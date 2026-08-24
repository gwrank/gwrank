module DiscordBot
  module Commands
    class TeamBuildCommands
      include SaveSupport

      def self.register(bot)
        new(bot).register
      end

      def initialize(bot)
        @bot = bot
      end

      def register
        register_schema
        register_dispatch
      end

      def dispatch(event)
        handle_teambuild(event)
      end

      private

      def register_schema
        @bot.register_application_command(:teambuild, 'Show a team build from a pawned2 export', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          cmd.string(:code, 'The pawned2 team build text, copied from paw.ned2', required: true)
          cmd.boolean(:verbose, 'Show skill names for each player (default: off)', required: false)
          cmd.string(:name, 'Override the embed title (default: auto)', required: false)
          cmd.string(:visibility, 'Save the team build to your account (default: private)', required: false,
                     choices: { 'Private' => 'private', 'Public' => 'public' })
        end
      end

      def register_dispatch
        @bot.application_command(:teambuild) { |event| dispatch(event) }
      end

      def handle_teambuild(event)
        entries = GW::PwndTemplate.decode!(event.options['code'].to_s.strip)
        verbose = event.options['verbose'] == true
        name = event.options['name'].to_s.strip.presence
        render_team(event, entries, verbose, name)
        save_posted_team(event, entries.first(MAX_ENTRIES), name)
      rescue GW::PwndTemplate::InvalidCode
        event.respond(content: "That doesn't look like a valid pawned2 team build.", ephemeral: true)
      rescue StandardError => e
        Rails.logger.error("Failed to render team build: #{e.class}: #{e.message}")
        event.respond(content: 'Something went wrong rendering that team build.', ephemeral: true)
      end

      # Saves exactly what was rendered: entries are already capped at
      # MAX_ENTRIES by the caller, and the saved name mirrors the compact
      # embed's auto title when the user didn't pick one.
      def save_posted_team(event, entries, name)
        save_to_account(event, entries, name || default_team_name(entries))
      end

      def default_team_name(entries)
        "Team Build (#{entries.size} #{entries.size == 1 ? 'player' : 'players'})"
      end

      # Discord allows at most 10 embeds and 10 file attachments per
      # message; a pawned2 export is capped at 8 players in practice, but a
      # crafted/corrupted one could carry more, so cap it explicitly rather
      # than let the API reject the post. In verbose mode each decodable
      # player contributes one embed and one attachment (its skill-strip
      # image), so 8 stays comfortably within both caps.
      MAX_ENTRIES = 8

      def render_team(event, entries, verbose, name = nil)
        return render_compact_team(event, entries.first(MAX_ENTRIES), name) unless verbose

        render_verbose_team(event, entries.first(MAX_ENTRIES))
      end

      # verbose:false's whole point is to compress a full team into one
      # screen: one embed, one grid image (one row of 8 skill icons per
      # player), and each player's template code as plain text underneath -
      # instead of the 8 separate image-carrying embeds verbose:true posts.
      def render_compact_team(event, entries, name = nil)
        readers = entries.map { |entry| decode_reader(entry) }
        strip_image = GW::SkillStripImage.build_grid(readers.map { |reader| grid_row(reader) }, numbered: true)

        embed = {
          title: name ? name.truncate(TITLE_LIMIT) : "Team Build (#{entries.size} #{entries.size == 1 ? 'player' : 'players'})",
          description: code_lines(entries, readers),
          image: { url: "attachment://#{File.basename(strip_image.path)}" }
        }

        event.respond(embeds: [embed], attachments: [strip_image])
      ensure
        strip_image&.close!
      end

      def grid_row(reader)
        return { primary: 0, secondary: 0, skills: Array.new(8, 0) } unless reader

        { primary: reader.primary, secondary: reader.secondary, skills: reader.skills }
      end

      def code_lines(entries, readers)
        entries.each_with_index.map do |entry, index|
          reader = readers[index]
          next "#{index + 1}. _(empty slot)_" if reader.nil? && entry.skills_code.blank?
          next "#{index + 1}. _(couldn't decode)_" unless reader

          "#{index + 1}. #{profession_abbr(reader)}: `#{reader.code}`"
        end.join("\n")
      end

      def profession_abbr(reader)
        primary = GW::TemplateReader::ProfessionAbbr[reader.primary]
        return primary if reader.secondary.zero?

        "#{primary}/#{GW::TemplateReader::ProfessionAbbr[reader.secondary]}"
      end

      def render_verbose_team(event, entries)
        strip_images = []
        embeds = entries.each_with_index.map do |entry, index|
          embed, strip_image = player_embed(entry, index)
          strip_images << strip_image if strip_image
          embed
        end

        event.respond(embeds: embeds, attachments: strip_images)
      ensure
        strip_images&.each(&:close!)
      end

      def player_embed(entry, index)
        reader = decode_reader(entry)
        return [placeholder_embed(entry, index), nil] unless reader

        full_embed(entry, index, reader)
      end

      def decode_reader(entry)
        return nil if entry.skills_code.blank?

        GW::TemplateReader.decode!(entry.skills_code)
      rescue GW::TemplateReader::InvalidCode
        nil
      end

      def placeholder_embed(entry, index)
        {
          title: title_for(entry, index, nil),
          description: entry.skills_code.blank? ? '(empty slot)' : "(couldn't decode)"
        }
      end

      def full_embed(entry, index, reader)
        strip_image = GW::SkillStripImage.build_grid([grid_row(reader)])
        embed = {
          title: title_for(entry, index, reader),
          description: attributes_text(reader.attributes),
          image: { url: "attachment://#{File.basename(strip_image.path)}" },
          fields: [{ name: 'Skills', value: skill_names(reader.skills) }],
          footer: { text: reader.code }
        }
        [embed, strip_image]
      end

      # Discord caps embed titles at 256 characters.
      TITLE_LIMIT = 256

      # player/slot_name come from the pawned2 description field, which can
      # decode to an arbitrarily large blob (up to ~3000 bytes) if the
      # export has no newline separator in that field. Truncate defensively
      # so one oddly-formed record can't blow Discord's 256-char title
      # limit and fail the whole team's response.
      NAME_PART_LIMIT = 50

      def title_for(entry, index, reader)
        label = reader ? profession_label(reader) : ''
        label += "#{label.empty? ? '' : ' — '}#{entry.player.truncate(NAME_PART_LIMIT)}" if entry.player
        label += "#{label.empty? ? '' : ' '}(#{entry.slot_name.truncate(NAME_PART_LIMIT)})" if entry.slot_name
        label = '(unknown)' if label.empty?
        "#{index + 1}. #{label}"
      end

      def profession_label(reader)
        primary = GW::TemplateReader::Profession[reader.primary]
        secondary = GW::TemplateReader::Profession[reader.secondary]
        secondary == 'None' ? primary : "#{primary} / #{secondary}"
      end

      def attributes_text(attributes)
        attributes
          .sort_by { |(_id, points)| -points }
          .map { |(id, points)| "**#{GW::Attributes.name_for(id)}** #{points}" }
          .join(' · ')
      end

      def skill_names(skill_ids)
        skill_ids.filter_map do |id|
          next if id.zero?

          skill = GW::SkillData.find(id)
          label = skill.is_elite ? "#{skill.name} (Elite)" : skill.name
          skill.cost_badge.empty? ? label : "#{label} #{skill.cost_badge}"
        end.join(', ')
      end
    end
  end
end

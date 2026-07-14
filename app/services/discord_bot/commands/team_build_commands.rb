module DiscordBot
  module Commands
    class TeamBuildCommands
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
        end
      end

      def register_dispatch
        @bot.application_command(:teambuild) { |event| dispatch(event) }
      end

      def handle_teambuild(event)
        entries = GW::PwndTemplate.decode!(event.options['code'].to_s.strip)
        render_team(event, entries)
      rescue GW::PwndTemplate::InvalidCode
        event.respond(content: "That doesn't look like a valid pawned2 team build.", ephemeral: true)
      rescue StandardError => e
        Rails.logger.error("Failed to render team build: #{e.class}: #{e.message}")
        event.respond(content: 'Something went wrong rendering that team build.', ephemeral: true)
      end

      # Discord allows at most 10 embeds and 10 file attachments per
      # message; a pawned2 export is capped at 8 players in practice, but a
      # crafted/corrupted one could carry more, so cap it explicitly rather
      # than let the API reject the post. Each decodable player contributes
      # one embed and one attachment (its skill-strip image), so 8 stays
      # comfortably within both caps.
      MAX_ENTRIES = 8

      def render_team(event, entries)
        strip_images = []
        embeds = entries.first(MAX_ENTRIES).each_with_index.map do |entry, index|
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
        strip_image = GW::SkillStripImage.build(reader.skills)
        embed = {
          title: title_for(entry, index, reader),
          description: attributes_text(reader.attributes),
          image: { url: "attachment://#{File.basename(strip_image.path)}" },
          fields: [{ name: 'Skills', value: skill_names(reader.skills) }],
          footer: { text: reader.code }
        }
        [embed, strip_image]
      end

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
          skill.is_elite ? "#{skill.name} (Elite)" : skill.name
        end.join(', ')
      end
    end
  end
end

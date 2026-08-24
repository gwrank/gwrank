module DiscordBot
  module Commands
    class BuildCommands
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
        handle_build(event)
      end

      private

      def register_schema
        @bot.register_application_command(:build, 'Show a build from a GW1 template code', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          cmd.string(:code, 'The template code, e.g. from the in-game Templates panel', required: true)
          cmd.boolean(:verbose, 'Show skill names and descriptions (default: off)', required: false)
          cmd.string(:visibility, 'Save the build to your account (default: private)', required: false,
                     choices: { 'Private' => 'private', 'Public' => 'public' })
        end
      end

      def register_dispatch
        @bot.application_command(:build) { |event| dispatch(event) }
      end

      def handle_build(event)
        code = event.options['code'].to_s.strip
        verbose = event.options['verbose'] == true
        reader = GW::TemplateReader.decode!(code)
        render_build(event, reader, verbose)
        save_to_account(event, [DiscordBot::SaveBuild::Entry.new(skills_code: reader.code, player: nil, slot_name: nil)], default_name(reader))
      rescue GW::TemplateReader::InvalidCode
        event.respond(content: "That doesn't look like a valid Guild Wars build code.", ephemeral: true)
      rescue StandardError => e
        Rails.logger.error("Failed to render build: #{e.class}: #{e.message}")
        event.respond(content: 'Something went wrong rendering that build.', ephemeral: true)
      end

      def default_name(reader)
        abbr = GW::TemplateReader::ProfessionAbbr[reader.primary]
        abbr += "/#{GW::TemplateReader::ProfessionAbbr[reader.secondary]}" unless reader.secondary.zero?
        "#{abbr} Build"
      end

      def render_build(event, reader, verbose)
        strip_image = GW::SkillStripImage.build_grid(
          [{ primary: reader.primary, secondary: reader.secondary, skills: reader.skills }]
        )

        event.respond(embeds: [build_embed(reader, strip_image, verbose)], attachments: [strip_image])
      ensure
        strip_image&.close!
      end

      def build_embed(reader, strip_image, verbose)
        primary_name = GW::TemplateReader::Profession[reader.primary]
        secondary_name = GW::TemplateReader::Profession[reader.secondary]
        title = secondary_name == 'None' ? primary_name : "#{primary_name} / #{secondary_name}"

        {
          title: title,
          description: verbose ? attributes_text(reader.attributes) : nil,
          image: { url: "attachment://#{File.basename(strip_image.path)}" },
          fields: verbose ? skill_fields(reader.skills) : [],
          footer: { text: reader.code }
        }
      end

      def attributes_text(attributes)
        attributes
          .sort_by { |(_id, points)| -points }
          .map { |(id, points)| "**#{GW::Attributes.name_for(id)}** #{points}" }
          .join(' · ')
      end

      def skill_fields(skill_ids)
        skill_ids.each_with_index.filter_map do |id, index|
          next if id.zero?

          skill = GW::SkillData.find(id)
          label = skill.is_elite ? "#{skill.name} (Elite)" : skill.name
          label += " #{skill.cost_badge}" unless skill.cost_badge.empty?
          { name: "#{index + 1}. #{label}", value: skill.description }
        end
      end
    end
  end
end

module DiscordBot
  module Commands
    class BuildCommands
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
        end
      end

      def register_dispatch
        @bot.application_command(:build) { |event| dispatch(event) }
      end

      def handle_build(event)
        code = event.options['code'].to_s.strip
        reader = GW::TemplateReader.decode!(code)
        render_build(event, reader)
      rescue GW::TemplateReader::InvalidCode
        event.respond(content: "That doesn't look like a valid Guild Wars build code.", ephemeral: true)
      rescue StandardError => e
        Rails.logger.error("Failed to render build: #{e.class}: #{e.message}")
        event.respond(content: 'Something went wrong rendering that build.', ephemeral: true)
      end

      def render_build(event, reader)
        profession_icon = File.open(profession_icon_path(reader.primary))
        strip_image = GW::SkillStripImage.build(reader.skills)

        event.respond(embeds: [build_embed(reader, profession_icon, strip_image)], attachments: [profession_icon, strip_image])
      ensure
        profession_icon&.close
        strip_image&.close!
      end

      def build_embed(reader, profession_icon, strip_image)
        primary_name = GW::TemplateReader::Profession[reader.primary]
        secondary_name = GW::TemplateReader::Profession[reader.secondary]
        title = secondary_name == 'None' ? primary_name : "#{primary_name} / #{secondary_name}"

        {
          title: title,
          description: attributes_text(reader.attributes),
          thumbnail: { url: "attachment://#{File.basename(profession_icon.path)}" },
          image: { url: "attachment://#{File.basename(strip_image.path)}" },
          fields: skill_fields(reader.skills),
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
          { name: "#{index + 1}. #{label}", value: skill.description }
        end
      end

      def profession_icon_path(profession_id)
        name = GW::TemplateReader::Profession[profession_id]
        Rails.root.join('app', 'assets', 'images', 'professions', "#{name}.png")
      end
    end
  end
end

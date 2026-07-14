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
        event.respond(embeds: [build_embed(entries)])
      rescue GW::PwndTemplate::InvalidCode
        event.respond(content: "That doesn't look like a valid pawned2 team build.", ephemeral: true)
      rescue StandardError => e
        Rails.logger.error("Failed to render team build: #{e.class}: #{e.message}")
        event.respond(content: 'Something went wrong rendering that team build.', ephemeral: true)
      end

      def build_embed(entries)
        {
          title: 'Team Build',
          fields: entries.each_with_index.map { |entry, index| player_field(entry, index) }
        }
      end

      def player_field(entry, index)
        reader = decode_reader(entry)
        { name: field_name(entry, index, reader), value: field_value(entry, reader) }
      end

      def decode_reader(entry)
        return nil if entry.skills_code.blank?

        GW::TemplateReader.decode!(entry.skills_code)
      rescue GW::TemplateReader::InvalidCode
        nil
      end

      def field_name(entry, index, reader)
        label = reader ? profession_label(reader) : ''
        label += "#{label.empty? ? '' : ' — '}#{entry.player}" if entry.player
        label += "#{label.empty? ? '' : ' '}(#{entry.slot_name})" if entry.slot_name
        label = '(unknown)' if label.empty?
        "#{index + 1}. #{label}"
      end

      def field_value(entry, reader)
        return '(empty slot)' if entry.skills_code.blank?
        return "(couldn't decode)" unless reader

        skill_names(reader.skills)
      end

      def profession_label(reader)
        primary = GW::TemplateReader::Profession[reader.primary]
        secondary = GW::TemplateReader::Profession[reader.secondary]
        secondary == 'None' ? primary : "#{primary} / #{secondary}"
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

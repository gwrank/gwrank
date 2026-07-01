module DiscordBot
  module Commands
    class ProfessionCommands
      PROFESSIONS = %w[warrior ranger monk necromancer mesmer elementalist assassin ritualist paragon dervish].freeze

      def self.register(bot)
        new(bot).register
      end

      def initialize(bot)
        @bot = bot
      end

      def register
        @bot.command(:professions, description: 'to set your professions') do |event|
          handle_professions_command(event)
        end

        @bot.button do |event|
          if event.custom_id&.start_with?('prof_')
            player = DiscordBot::FindOrCreatePlayer.call(event)
            handle_professions_button(event, player)
          end
        end
      end

      private

      def handle_professions_command(event)
        player = DiscordBot::FindOrCreatePlayer.call(event)

        event.send_message!(has_components: true) do |_, view|
          professions_container(view, player)
        end
      end

      def handle_professions_button(event, player)
        profession = event.custom_id.split('_')[1]
        return unless PROFESSIONS.include?(profession)

        player.update("is_#{profession}" => !player.public_send("is_#{profession}"))

        event.interaction.update_message(has_components: true) do |_, view|
          professions_container(view, player)
        end
      end

      def professions_container(view, player)
        view.container do |container|
          container.section do |section|
            section.text_display(content: "### Professions Panel\nYour current professions:\n#{player.professions_text.presence || 'No professions set'}")
            section.thumbnail(url: 'https://gwrank.com/assets/background-a4004a29.jpg')
          end
          container.row do |row|
            row.button(label: 'Warrior', style: player.is_warrior ? :success : :secondary, custom_id: 'prof_warrior')
            row.button(label: 'Ranger', style: player.is_ranger ? :success : :secondary, custom_id: 'prof_ranger')
          end
          container.row do |row|
            row.button(label: 'Monk', style: player.is_monk ? :success : :secondary, custom_id: 'prof_monk')
            row.button(label: 'Necromancer', style: player.is_necromancer ? :success : :secondary, custom_id: 'prof_necromancer')
          end
          container.row do |row|
            row.button(label: 'Mesmer', style: player.is_mesmer ? :success : :secondary, custom_id: 'prof_mesmer')
            row.button(label: 'Elementalist', style: player.is_elementalist ? :success : :secondary, custom_id: 'prof_elementalist')
          end
          container.row do |row|
            row.button(label: 'Assassin', style: player.is_assassin ? :success : :secondary, custom_id: 'prof_assassin')
            row.button(label: 'Ritualist', style: player.is_ritualist ? :success : :secondary, custom_id: 'prof_ritualist')
          end
          container.row do |row|
            row.button(label: 'Paragon', style: player.is_paragon ? :success : :secondary, custom_id: 'prof_paragon')
            row.button(label: 'Dervish', style: player.is_dervish ? :success : :secondary, custom_id: 'prof_dervish')
          end
        end
      end
    end
  end
end

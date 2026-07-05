module DiscordBot
  module Commands
    class PlayerCommands
      PROFESSIONS = %w[warrior ranger monk necromancer mesmer elementalist assassin ritualist paragon dervish].freeze
      PROFESSION_CHOICES = PROFESSIONS.to_h { |profession| [profession.capitalize, profession] }.freeze

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
        case event.subcommand
        when :register then handle_register(event)
        when :igname then handle_igname(event)
        when :claim then handle_claim(event)
        when :professions then handle_professions(event)
        end
      end

      private

      def register_schema
        @bot.register_application_command(:player, 'Manage your player profile', server_id: ENV['DISCORD_SERVER_ID']) do |cmd|
          cmd.subcommand(:register, 'Set your in-game name') do |sub|
            sub.string(:igname, 'Your in-game character name', required: true)
          end

          cmd.subcommand(:igname, "Look up a player's in-game name") do |sub|
            sub.user(:member, 'The player to look up', required: true)
          end

          cmd.subcommand(:claim, 'Claim a character name') do |sub|
            sub.string(:igname, 'The character name to claim', required: true)
          end

          cmd.subcommand(:professions, 'View or toggle your professions') do |sub|
            sub.string(:profession, 'Profession to toggle on/off', required: false, choices: PROFESSION_CHOICES)
          end
        end
      end

      def register_dispatch
        handler = @bot.application_command(:player)
        %i[register igname claim professions].each { |name| handler.subcommand(name) { |event| dispatch(event) } }
      end

      def handle_register(event)
        igname = event.options['igname'].to_s.strip
        player = DiscordBot::FindOrCreatePlayer.call(event)
        player.update(igname: igname)

        event.respond(content: "<@#{event.user.id}>, your in-game name is now **#{player.igname}**.")
      end

      def handle_igname(event)
        found_player = Player.find_by(uid: event.options['member'])

        if found_player&.igname.present?
          event.respond(content: "<@#{event.user.id}> (**#{found_player.igname}**)")
        else
          event.respond(content: "<@#{event.user.id}> (in-game name not found)")
        end
      end

      def handle_claim(event)
        player = DiscordBot::FindOrCreatePlayer.call(event)

        original_igname = event.options['igname'].strip
        character_igname = original_igname.titleize
        character = Character.find_by_igname(original_igname)

        if character.present?
          claim_existing_character(event, character, character_igname, player)
        else
          create_and_claim_character(event, character_igname, player)
        end
      end

      def claim_existing_character(event, character, character_igname, player)
        if character.claimable_by?(player)
          character.update(igname: character_igname, player: player)
          TeamPlayer.where(igname: character_igname).update_all(character_id: character.id, igname: character_igname, player_id: player.id)
          player.set_professions_from_team_players
          player.save

          event.respond(content: "<@#{event.user.id}>, you have successfully claimed the character **#{character_igname}**!")
          return
        end

        existing_claim = CharacterClaim.find_by(character: character, player: player, status: 'pending')
        if existing_claim
          event.respond(content: "<@#{event.user.id}>, you already have a pending claim for **#{character_igname}**. A moderator will review it shortly.")
        else
          CharacterClaim.create!(character: character, player: player, claimed_by: player, claimed_igname: character_igname, status: 'pending')
          event.respond(content: "<@#{event.user.id}>, your claim for **#{character_igname}** has been submitted for moderator verification. Once approved, the character will be linked to your profile.")
        end
      end

      def create_and_claim_character(event, character_igname, player)
        character = Character.create!(igname: character_igname, player: player)
        TeamPlayer.where(igname: character_igname).update_all(character_id: character.id, player_id: player.id)
        player.set_professions_from_team_players
        player.save

        event.respond(content: "<@#{event.user.id}>, you have successfully created and claimed the character **#{character.igname}**!")
      end

      def handle_professions(event)
        player = DiscordBot::FindOrCreatePlayer.call(event)
        profession = event.options['profession']

        player.update("is_#{profession}" => !player.public_send("is_#{profession}")) if profession.present?

        event.respond(content: "<@#{event.user.id}>, your current professions: #{player.professions_text.presence || 'No professions set'}")
      end
    end
  end
end

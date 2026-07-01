# app/services/discord_bot/commands/claim_commands.rb
module DiscordBot
  module Commands
    class ClaimCommands
      def self.register(bot)
        new(bot).register
      end

      def initialize(bot)
        @bot = bot
      end

      def register
        @bot.command(:igname, description: 'to find the in-game name of a player') do |event, player|
          handle_igname_command(event, player)
        end

        @bot.command(:claim, description: 'to claim your in-game character name') do |event, *igname|
          handle_claim_command(event, igname)
        end
      end

      private

      def handle_igname_command(event, player)
        if player.present? && player.starts_with?('<@!') && player.ends_with?('>')
          uid = player.delete_prefix('<@!').delete_suffix('>')
          found_player = Player.find_by(uid: uid)
          if found_player.present?
            event.respond "<@#{event.user.id}> (**#{found_player.igname}**)"
          else
            event.respond "<@#{event.user.id}> (in-game name not found)"
          end
        else
          event.respond "<@#{event.user.id}> (invalid player)"
        end
      end

      def handle_claim_command(event, igname)
        if igname.blank? || igname.empty?
          event.respond "<@#{event.user.id}>, please provide a character name to claim. Usage: *!claim Your Character Name*"
          return
        end

        player = DiscordBot::FindOrCreatePlayer.call(event)

        original_igname = igname.join(' ').strip
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

          event.respond "<@#{event.user.id}>, you have successfully claimed the character **#{character_igname}**!"
          return
        end

        existing_claim = CharacterClaim.find_by(character: character, player: player, status: 'pending')
        if existing_claim
          event.respond "<@#{event.user.id}>, you already have a pending claim for **#{character_igname}**. A moderator will review it shortly."
        else
          CharacterClaim.create!(character: character, player: player, claimed_by: player, claimed_igname: character_igname, status: 'pending')
          event.respond "<@#{event.user.id}>, your claim for **#{character_igname}** has been submitted for moderator verification. Once approved, the character will be linked to your profile."
        end
      end

      def create_and_claim_character(event, character_igname, player)
        character = Character.create!(igname: character_igname, player: player)
        TeamPlayer.where(igname: character_igname).update_all(character_id: character.id, player_id: player.id)
        player.set_professions_from_team_players
        player.save

        event.respond "<@#{event.user.id}>, you have successfully created and claimed the character **#{character.igname}**!"
      end
    end
  end
end

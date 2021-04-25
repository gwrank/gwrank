# frozen_string_literal: true

namespace :players do
  task link_to_team_players: :environment do
    Player.all.each do |player|
      player.characters.each do |character|
        TeamPlayer.where(igname: character.igname).update_all(
          character_id: character.id,
          player_id: player.id
        )
      end
    end
  end
end

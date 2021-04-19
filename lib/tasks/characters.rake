# frozen_string_literal: true

namespace :characters do
  task import_from_players: :environment do
    Player.all.each do |player|
      character = Character.where(igname: player.igname).first_or_create!
      character.update(player: player)
    end
  end

  task import_from_team_players: :environment do
    TeamPlayer.all.each do |team_player|
      character = Character.where(igname: team_player.igname).first_or_create!(
        profession: team_player.profession
      )
      team_player.update(character: character)
    end
  end

  task link_to_players: :environment do
    Player.all.each do |player|
      character = Character.find_by(igname: player.igname)
      character.update(player: player) if character.present?
    end
  end
end

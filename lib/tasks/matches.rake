namespace :matches do
  task add_average_dpm_to_team_players: :environment do
    Match.all.find_each(&:add_average_dpm_to_team_players!)
  end
end

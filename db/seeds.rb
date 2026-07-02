# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# In development, this also creates fake historical scrim data (players, rosters, results, an
# elo history, a live queue, and one in-progress scrim) so local pages (homepage, /scrims,
# /scrims/:id) have something to show.

Rails.application.load_tasks unless Rake::Task.task_defined?('professions:import')
Rake::Task['professions:import'].invoke

if Rails.env.development?
  SEED_EMAIL_DOMAIN = 'seed.gwrank.local'.freeze

  puts 'Clearing previously seeded scrim data...'
  seeded_player_ids = Player.where('email LIKE ?', "%@#{SEED_EMAIL_DOMAIN}").pluck(:id)
  seeded_team_ids = TeamPlayer.where(player_id: seeded_player_ids).select(:team_id).distinct.pluck(:team_id)
  Scrim.where(team_a_id: seeded_team_ids).or(Scrim.where(team_b_id: seeded_team_ids)).destroy_all
  Registration.where(player_id: seeded_player_ids).destroy_all
  Team.where(id: seeded_team_ids).destroy_all
  Player.where(id: seeded_player_ids).destroy_all

  puts 'Creating fake players...'

  IGNAMES = [
    'Shadow Blade Kex', 'Holy Light Mira', 'Iron Fist Dorn', 'Wind Walker Tess',
    'Bone Fiend Vex', 'Grave Digger Roth', 'Storm Caller Zia', 'Silent Arrow Fenn',
    'Blood Moon Yara', 'Frost Bite Kael', 'Spirit Weaver Lina', 'War Drum Bok',
    'Night Howl Sera', 'Sun Ray Adan', 'Death Toll Nix', 'Thunder Claw Rix',
    'Ash Wraith Nym', 'Golden Spear Odo', 'Dark Verse Isla', 'Steel Song Gwen',
    'Ember Fall Tork', 'Moon Sickle Faye', 'Crimson Vow Halden', 'Whisper Fang Ilse'
  ].freeze

  PROFESSION_FLAGS = %i[
    is_warrior is_ranger is_monk is_necromancer is_mesmer
    is_elementalist is_assassin is_ritualist is_paragon is_dervish
  ].freeze

  players = IGNAMES.each_with_index.map do |igname, index|
    Player.create!(
      email: "player#{index + 1}@#{SEED_EMAIL_DOMAIN}",
      username: "player#{index + 1}",
      igname: igname,
      password: 'password123',
      password_confirmation: 'password123',
      elo_rating: 1100 + rand(300),
      PROFESSION_FLAGS[index % PROFESSION_FLAGS.size] => true
    )
  end

  puts "Created #{players.count} fake players."

  puts 'Playing out historical scrims...'

  SCRIMS_COUNT = 12
  scrim_dates = SCRIMS_COUNT.times.map { |i| (SCRIMS_COUNT - i).days.ago - rand(0..12).hours }.sort

  scrim_dates.each do |played_at|
    roster = players.sample(Scrims::FormTeams::QUEUE_SIZE)
    result = Scrims::FormTeams.call(roster)
    scrim = Scrims::FormTeams.persist!(result)

    team_a_wins, team_b_wins = [true, false].sample ? [2, [0, 1].sample] : [[0, 1].sample, 2]
    winner_team_id = team_a_wins > team_b_wins ? scrim.team_a_id : scrim.team_b_id

    scrim.update_columns(
      team_a_wins: team_a_wins,
      team_b_wins: team_b_wins,
      winner_team_id: winner_team_id,
      created_at: played_at,
      updated_at: played_at
    )
    scrim.calculate_elo!
  end

  puts "Created #{SCRIMS_COUNT} decided scrims with elo history."

  puts 'Forming one in-progress scrim...'
  in_progress_roster = players.sample(Scrims::FormTeams::QUEUE_SIZE)
  in_progress_result = Scrims::FormTeams.call(in_progress_roster)
  in_progress_scrim = Scrims::FormTeams.persist!(in_progress_result)
  in_progress_scrim.update_columns(team_a_wins: 1, team_b_wins: 0, created_at: 15.minutes.ago, updated_at: 5.minutes.ago)
  puts "In-progress scrim ##{in_progress_scrim.id} created (1-0, no winner yet)."

  puts 'Registering a partial live queue...'
  queued_players = (players - in_progress_roster).sample(7)
  queued_players.each { |player| Registration.create!(player: player, registered_at: Time.current) }
  puts "#{queued_players.count}/16 players registered in the live queue."

  puts 'Done.'
end

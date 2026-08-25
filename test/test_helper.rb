ENV['RAILS_ENV'] ||= 'test'
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

Dir[Rails.root.join("test/support/**/*.rb")].each { |file| require file }

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...

  def create_player(elo_rating: nil, professions: [], **attrs)
    defaults = {
      email: "player-#{SecureRandom.hex(6)}@example.com",
      username: "player-#{SecureRandom.hex(4)}",
      password: 'password123',
      password_confirmation: 'password123',
      elo_rating: elo_rating
    }
    player = Player.new(defaults.merge(attrs))
    professions.each { |flag| player.public_send("#{flag}=", true) }
    player.save!
    player
  end

  def auth_headers(player)
    { "Authorization" => "Bearer #{player.api_token}", "Accept" => "application/json" }
  end

  def load_zcx(name = "gvg_split")
    JSON.parse(File.read(Rails.root.join("test/fixtures/files/teambuilds/#{name}.zcx.json")))
  end

  def create_guild(name: "Guild #{SecureRandom.hex(4)}")
    Guild.create!(name: name, tag: name.gsub(/[^a-zA-Z]/, '')[0, 4].upcase)
  end

  def create_tournament(year: 2025, month: 6, date: Date.new(2025, 6, 15))
    Tournament.create!(tournament_type: 'mat', year: year, month: month, date: date)
  end

  def create_character(igname: "Char#{SecureRandom.hex(3)}")
    Character.create!(igname: igname)
  end

  def create_match(played_at: Time.zone.now, round: 4, number_on_round: 1,
                   tournament: nil, guild_a: nil, guild_b: nil)
    guild_a ||= create_guild
    guild_b ||= create_guild
    match = Match.new(played_at: played_at, round: round,
                      number_on_round: number_on_round, tournament: tournament)
    team_a = match.teams.build(guild: guild_a, rank: 1)
    team_b = match.teams.build(guild: guild_b, rank: 2)
    [team_a, team_b].each do |team|
      team.team_players.build(
        player: create_player,
        igname: "tp-#{SecureRandom.hex(3)}",
        position: 0,
        profession: professions(:warrior)
      )
    end
    match.save!
    match
  end
end

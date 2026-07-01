ENV['RAILS_ENV'] ||= 'test'
require_relative "../config/environment"
require "rails/test_help"

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
end

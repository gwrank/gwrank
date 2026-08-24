# frozen_string_literal: true

module ApiHelpers
  def create_api_player
    Player.create!(
      email: "player-#{SecureRandom.hex(6)}@example.com",
      username: "player-#{SecureRandom.hex(4)}",
      password: 'password123',
      password_confirmation: 'password123'
    )
  end

  def load_zcx(name = 'gvg_split')
    JSON.parse(File.read(Rails.root.join("test/fixtures/files/teambuilds/#{name}.zcx.json")))
  end

  def auth_header_for(player)
    { 'Authorization' => "Bearer #{player.api_token}", 'Accept' => 'application/json' }
  end
end

RSpec.configure do |config|
  config.include ApiHelpers
end

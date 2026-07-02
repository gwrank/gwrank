require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "shows the current queue count and a decided scrim's result" do
    create_player.registrations.create!(registered_at: Time.current)

    team_a = Team.create!
    team_b = Team.create!
    Scrim.create!(team_a: team_a, team_b: team_b, team_a_wins: 2, team_b_wins: 0, winner_team_id: team_a.id)

    get root_path

    assert_response :success
    assert_select 'body', text: /1\/16 registered/
    assert_select 'body', text: /2-0/
  end

  test "renders cleanly with an empty queue and no decided scrims" do
    get root_path

    assert_response :success
    assert_select 'body', text: /0\/16 registered/
    assert_select 'body', text: /0 scrims played/
  end
end

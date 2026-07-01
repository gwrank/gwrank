require "test_helper"

class ScrimsControllerTest < ActionDispatch::IntegrationTest
  test "show renders a scrim's rosters and score" do
    team_a = Team.create!
    team_a.team_players.create!(player: create_player(elo_rating: 1200, username: 'CaptainA'), profession: professions(:warrior), is_captain: true)
    team_b = Team.create!
    team_b.team_players.create!(player: create_player(elo_rating: 1200, username: 'CaptainB'), profession: professions(:monk), is_captain: true)
    scrim = Scrim.create!(team_a: team_a, team_b: team_b, team_a_wins: 2, team_b_wins: 1, winner_team_id: team_a.id)

    get scrim_path(scrim)

    assert_response :success
    assert_select 'body', text: /CaptainA/
    assert_select 'body', text: /2-1/
  end
end

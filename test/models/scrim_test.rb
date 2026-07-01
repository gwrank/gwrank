require "test_helper"

class ScrimTest < ActiveSupport::TestCase
  test "loser_team returns whichever of team_a/team_b did not win" do
    team_a = Team.create!
    team_b = Team.create!
    scrim = Scrim.create!(team_a: team_a, team_b: team_b, winner_team_id: team_a.id)

    assert_equal team_b, scrim.loser_team
  end

  test "loser_team is nil when no winner is set yet" do
    scrim = Scrim.create!(team_a: Team.create!, team_b: Team.create!)

    assert_nil scrim.loser_team
  end

  test "calculate_elo! updates elo for both rosters" do
    winner_player = create_player(elo_rating: 1200)
    loser_player = create_player(elo_rating: 1200)

    team_a = Team.create!
    team_a.team_players.create!(player: winner_player, profession: professions(:warrior))
    team_b = Team.create!
    team_b.team_players.create!(player: loser_player, profession: professions(:monk))

    scrim = Scrim.create!(team_a: team_a, team_b: team_b, winner_team_id: team_a.id)
    scrim.calculate_elo!

    assert_equal 1216, winner_player.reload.elo_rating
    assert_equal 1184, loser_player.reload.elo_rating
  end

  test "in_progress scope only returns scrims with rosters and no winner yet" do
    forming = Scrim.create!
    in_progress = Scrim.create!(team_a: Team.create!, team_b: Team.create!)
    decided = Scrim.create!(team_a: Team.create!, team_b: Team.create!, winner_team_id: Team.create!.id)

    assert_equal [in_progress], Scrim.in_progress.to_a
    assert_not_includes Scrim.in_progress, forming
    assert_not_includes Scrim.in_progress, decided
  end
end

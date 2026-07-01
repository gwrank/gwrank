require "test_helper"

class EloCalculatorTest < ActiveSupport::TestCase
  test "raises winner elo, lowers loser elo, and records opponent-elo stats" do
    winner_player = create_player(elo_rating: 1200)
    loser_player = create_player(elo_rating: 1200)

    winner_team = Team.create!
    winner_team.team_players.create!(player: winner_player, profession: professions(:warrior))

    loser_team = Team.create!
    loser_team.team_players.create!(player: loser_player, profession: professions(:monk))

    EloCalculator.new(winner_team: winner_team, loser_team: loser_team).call!

    winner_player.reload
    loser_player.reload

    assert_equal 1216, winner_player.elo_rating # 1200 + 32 * (1 - 0.5)
    assert_equal 1184, loser_player.elo_rating  # 1200 + 32 * (0 - 0.5)
    assert_equal 1, winner_player.elo_matches
    assert_equal 1, loser_player.elo_matches

    winner_team_player = winner_team.team_players.first
    loser_team_player = loser_team.team_players.first
    assert_equal 1200, winner_team_player.team_player_stats.find_by(stat_key: 'opponent_elo_at_match').stat_value
    assert_equal 1200, loser_team_player.team_player_stats.find_by(stat_key: 'team_elo_at_match').stat_value
  end

  test "defaults missing elo to 1200 for both players and team averages" do
    winner_player = create_player(elo_rating: nil)
    loser_player = create_player(elo_rating: nil)

    winner_team = Team.create!
    winner_team.team_players.create!(player: winner_player, profession: professions(:warrior))
    loser_team = Team.create!
    loser_team.team_players.create!(player: loser_player, profession: professions(:monk))

    EloCalculator.new(winner_team: winner_team, loser_team: loser_team).call!

    assert_equal 1216, winner_player.reload.elo_rating
    assert_equal 1184, loser_player.reload.elo_rating
  end
end

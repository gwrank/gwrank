require "test_helper"

module Scrims
  class RecordGameResultTest < ActiveSupport::TestCase
    def build_scrim
      team_a = Team.create!
      team_a.team_players.create!(player: create_player(elo_rating: 1200), profession: professions(:warrior))
      team_b = Team.create!
      team_b.team_players.create!(player: create_player(elo_rating: 1200), profession: professions(:monk))
      Scrim.create!(team_a: team_a, team_b: team_b)
    end

    test "tallies a game win without deciding the series before 2 wins" do
      scrim = build_scrim

      result = Scrims::RecordGameResult.call!(scrim: scrim, winner: :a)

      assert_equal 1, result.team_a_wins
      assert_equal 0, result.team_b_wins
      assert_nil result.winner_team_id
    end

    test "decides the series and calculates elo exactly once when a team reaches 2 wins" do
      scrim = build_scrim
      winner_player = scrim.team_a.players.first
      loser_player = scrim.team_b.players.first

      Scrims::RecordGameResult.call!(scrim: scrim, winner: :a)
      result = Scrims::RecordGameResult.call!(scrim: scrim, winner: :a)

      assert_equal 2, result.team_a_wins
      assert_equal scrim.team_a_id, result.winner_team_id
      assert_equal 1216, winner_player.reload.elo_rating
      assert_equal 1184, loser_player.reload.elo_rating
    end

    test "raises if called again after the series is already decided" do
      scrim = build_scrim
      Scrims::RecordGameResult.call!(scrim: scrim, winner: :a)
      Scrims::RecordGameResult.call!(scrim: scrim, winner: :a)

      assert_raises(ArgumentError) do
        Scrims::RecordGameResult.call!(scrim: scrim, winner: :b)
      end
    end
  end
end

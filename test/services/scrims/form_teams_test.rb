require "test_helper"

module Scrims
  class FormTeamsTest < ActiveSupport::TestCase
    test "splits a bucket by elo using a snake draft to keep both teams balanced" do
      # 4 monks, descending elo: 1600, 1400, 1200, 1000
      # snake pattern A,B,B,A => team_a gets 1600+1000=2600, team_b gets 1400+1200=2600
      monks = [1600, 1400, 1200, 1000].map { |elo| create_player(elo_rating: elo, professions: [:is_monk]) }
      others = Array.new(12) { create_player(elo_rating: 1200) }

      result = Scrims::FormTeams.call(monks + others)

      team_a_monks = result.team_a.select { |a| a.player.is_monk? }
      team_b_monks = result.team_b.select { |a| a.player.is_monk? }
      assert_equal 2600, team_a_monks.sum { |a| a.player.elo_rating }
      assert_equal 2600, team_b_monks.sum { |a| a.player.elo_rating }
    end

    test "assigns profession_name from the bucket that captured the player, not just any true flag" do
      # multi-classer: monk AND warrior both true - the monk bucket goes first, so this
      # player must be resolved as Monk, not Warrior, even though warrior comes first
      # in Player#professions' overall flag order.
      multiclasser = create_player(elo_rating: 1200, professions: [:is_monk, :is_warrior])
      others = Array.new(15) { create_player(elo_rating: 1200) }

      result = Scrims::FormTeams.call([multiclasser] + others)

      assignment = (result.team_a + result.team_b).find { |a| a.player == multiclasser }
      assert_equal 'Monk', assignment.profession_name
    end

    test "players with no profession flags set are assigned the None profession" do
      players = Array.new(16) { create_player(elo_rating: 1200) }

      result = Scrims::FormTeams.call(players)

      assert (result.team_a + result.team_b).all? { |a| a.profession_name == 'None' }
    end

    test "handles zero players in a bucket without error" do
      # zero monks registered - the monk bucket is empty, frontline/midline/other absorb everyone
      players = Array.new(16) { create_player(elo_rating: 1200, professions: [:is_warrior]) }

      result = Scrims::FormTeams.call(players)

      assert_equal 8, result.team_a.size
      assert_equal 8, result.team_b.size
    end

    test "keeps team sizes at 8-8 even when bucket sizes aren't multiples of four" do
      # 2 monks + 5 frontliners + 9 midliners + 0 "other" = 16. Each bucket's
      # own snake draft resets to index 0, so without a size-correction pass
      # this would produce a 9-7 split (2 buckets sized 4k+1 both biasing
      # toward team A) instead of 8-8.
      monks = Array.new(2) { create_player(elo_rating: 1200, professions: [:is_monk]) }
      frontliners = Array.new(5) { create_player(elo_rating: 1200, professions: [:is_warrior]) }
      midliners = Array.new(9) { create_player(elo_rating: 1200, professions: [:is_ranger]) }

      result = Scrims::FormTeams.call(monks + frontliners + midliners)

      assert_equal 8, result.team_a.size
      assert_equal 8, result.team_b.size
    end

    test "the highest-elo player on each team becomes that team's captain" do
      players = (1..16).map { |i| create_player(elo_rating: 1000 + i) }

      result = Scrims::FormTeams.call(players)

      assert_equal 1, result.team_a.count(&:captain)
      assert_equal 1, result.team_b.count(&:captain)
      team_a_top_elo = result.team_a.max_by { |a| a.player.elo_rating }
      team_b_top_elo = result.team_b.max_by { |a| a.player.elo_rating }
      assert team_a_top_elo.captain
      assert team_b_top_elo.captain
    end

    test "call! persists a Scrim with two 8-player Teams and sets captains" do
      players = (1..16).map { |i| create_player(elo_rating: 1000 + i) }
      players.each { |p| p.registrations.create!(registered_at: Time.current) }

      scrim = Scrims::FormTeams.call!

      assert scrim.persisted?
      assert_equal 8, scrim.team_a.team_players.count
      assert_equal 8, scrim.team_b.team_players.count
      assert scrim.captain_a_id.present?
      assert scrim.captain_b_id.present?
      assert_equal 0, scrim.team_a_wins
      assert_equal 0, scrim.team_b_wins
    end
  end
end

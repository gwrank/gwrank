require 'test_helper'

# == Schema Information
#
# Table name: matches
#
#  id                :bigint           not null, primary key
#  elo_calculated    :boolean
#  exported_at       :datetime
#  imported_at       :datetime
#  json              :jsonb
#  name              :string
#  number_on_round   :integer
#  played_at         :datetime
#  round             :integer
#  slug              :string
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  imported_by_id    :bigint
#  loser_team_id     :integer
#  memorial_match_id :integer
#  tournament_id     :bigint
#  winner_team_id    :integer
#
# Indexes
#
#  index_matches_on_imported_by_id    (imported_by_id)
#  index_matches_on_played_at         (played_at)
#  index_matches_on_played_at_and_id  (played_at,id)
#  index_matches_on_tournament_id     (tournament_id)
#
# Foreign Keys
#
#  fk_rails_...  (imported_by_id => players.id)
#  fk_rails_...  (tournament_id => tournaments.id)
#
class MatchTest < ActiveSupport::TestCase
  test 'title uses preloaded teams without extra queries' do
    match = create_match
    preloaded = Match.where(id: match.id).includes(teams: :guild).first
    expected_title = match_title_for(match)
    assert_no_queries { assert_equal expected_title, preloaded.title }
  end

  test 'title falls back to batched includes when teams are not loaded' do
    match = create_match
    fresh = Match.find(match.id)
    assert_equal match_title_for(match), fresh.title
  end

  test "ordered_teams returns teams sorted by rank" do
    match = Match.create!(
      played_at: Time.zone.now,
      round: 4,
      number_on_round: 1,
      tournament: create_tournament
    )
    high_rank_team = match.teams.create!(guild: create_guild, rank: 2)
    low_rank_team = match.teams.create!(guild: create_guild, rank: 1)
    assert_equal [low_rank_team.id, high_rank_team.id], match.ordered_teams.map(&:id)
    assert_equal [1, 2], match.ordered_teams.map(&:rank)
  end

  test "ordered_teams sorts in memory when teams are preloaded" do
    match = create_match
    match.teams.order(:id).first.update!(rank: 2)
    match.teams.order(:id).last.update!(rank: 1)
    fresh = Match.includes(:teams).find(match.id)
    assert_no_queries { assert_equal [1, 2], fresh.ordered_teams.map(&:rank) }
  end

  private

  def match_title_for(match)
    "#{match.teams.first.guild.name_with_tag} vs. #{match.teams.second.guild.name_with_tag}"
  end
end

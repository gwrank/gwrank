# Time-Based GWR Ratings Implementation Plan

## Context

The GWR (Guild Wars Rating) system currently stores a single cumulative ELO rating per player (`players.elo_rating`). Users want to see GWR ratings broken down by time intervals:
1. **All-time GWR** - current implementation
2. **Last 12 months GWR** - rolling 12-month window
3. **Last 30 days GWR** - rolling 30-day window

This will provide better insight into current form vs historical performance.

## Data Model Understanding

```
Match (played_at: datetime)
  └── Teams
        └── TeamPlayers (player_id, created_at, profession_id)
              └── Players (elo_rating, elo_matches)
```

Key insights:
- `Match.played_at` stores when the match occurred
- ELO is calculated incrementally in `Match#calculate_elo!` (lines 272-326)
- ELO is stored as a running total on the Player model
- To calculate time-based ELO, we need to "replay" matches within a time window

## Approach

### Recommended: Calculated on-Demand via Scope

Since ELO is cumulative and match history can be replayed chronologically, we'll:

1. **Add scope methods to Player model** to fetch matches within time windows
2. **Create calculated ELO methods** that replay matches within the specified time window
3. **Add virtual attributes** to return the calculated values

This approach:
- No schema changes needed
- Always accurate (real-time calculation)
- Can be cached if performance becomes an issue
- Clean separation of concerns

### Alternative Approaches Considered

1. **Stored snapshots** - Periodically calculate and store time-window ELOs
   - Pros: Fast reads
   - Cons: Stale data, requires background jobs, more storage

2. **Per-match ELO deltas** - Store ELO changes per match
   - Pros: Could sum deltas for any window
   - Cons: Requires schema changes, migration complexity

## Implementation Details

### Files to Modify

1. **app/models/player.rb**
   - Add `matches_in_window(from_date, to_date)` scope
   - Add `calculate_elo_for_window(from_date, to_date)` method
   - Add `elo_last_12_months` and `elo_last_30_days` methods

2. **app/controllers/statistics_controller.rb**
   - Update calculations to fetch time-window ELOs for top players
   - Add `@top_elo_players_last_year` and `@top_elo_players_last_month`

3. **app/views/statistics/index.html.erb**
   - Add tabs/toggle for time periods (All-time / Last Year / Last Month)
   - Display the appropriate GWR ratings based on selected period
   - Similar structure to the profession navigation already in place

4. **app/models/guild.rb**
   - Add `avg_elo_last_12_months` and `avg_elo_last_30_days` methods
   - Update guild calculations for time-based averages

## Method Signatures

```ruby
# Player model
def matches_played_in_window(from_date, to_date)
  # Returns team_players with matches in the time window
end

def elo_rating_for_window(from_date, to_date)
  # Replays ELO calculations for matches in window, returns calculated ELO
end

def elo_last_12_months
  elo_rating_for_window(12.months.ago, Time.current)
end

def elo_last_30_days
  elo_rating_for_window(30.days.ago, Time.current)
end
```

## Performance Considerations

1. **Index on matches.played_at** - Essential for time-based queries
2. **N+1 query prevention** - Use `includes`/`joins` appropriately
3. **Caching strategy** - Consider caching window calculations for top 100 players if needed

## Testing Strategy

1. Create matches with known dates and ELO outcomes
2. Verify window calculations match expected values
3. Test edge cases: no matches in window, matches exactly on boundary dates
4. Compare all-time calculation matches current behavior

## Verification Steps

1. Run `rake db:migrate` if adding index
2. Visit `/statistics` and verify:
   - All-time rankings display correctly (existing behavior)
   - New tabs/buttons show time-filtered rankings
   - Different time periods show different rankings where appropriate
3. Check SQL logs for N+1 queries and optimize if needed

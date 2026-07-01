module Scrims
  class FormTeams
    QUEUE_SIZE = 16
    DEFAULT_ELO = 1200
    SNAKE_PATTERN = %i[a b b a].freeze

    # Same bucket definitions and processing order as the current !newteams
    # handler: a player is captured by the first bucket they match, so a
    # multi-classer's profession for this scrim is whichever bucket claims
    # them first. Deliberately narrower than Player.backliners (which also
    # includes ritualists) - ritualists fall into the midline bucket, exactly
    # like today.
    BUCKETS = [
      [:is_monk],
      %i[is_warrior is_assassin is_dervish],
      %i[is_ranger is_necromancer is_mesmer is_elementalist is_ritualist is_paragon]
    ].freeze

    FLAG_TO_PROFESSION_NAME = {
      is_warrior: 'Warrior', is_ranger: 'Ranger', is_monk: 'Monk',
      is_necromancer: 'Necromancer', is_mesmer: 'Mesmer', is_elementalist: 'Elementalist',
      is_assassin: 'Assassin', is_ritualist: 'Ritualist', is_paragon: 'Paragon', is_dervish: 'Dervish'
    }.freeze

    Assignment = Struct.new(:player, :profession_name, :captain, keyword_init: true)
    Result = Struct.new(:team_a, :team_b, keyword_init: true)

    def self.call(players)
      new(players).call
    end

    # NOTE: call (and balance_sizes! internally) assumes an even-sized,
    # QUEUE_SIZE-length roster - only call! enforces that. Don't call
    # `Scrims::FormTeams.call` directly with an odd-length or non-16 array;
    # balance_sizes! only guarantees termination when team_a.size and
    # team_b.size can reach parity, which requires an even total.
    def self.call!
      players = Player.in_queue.first(QUEUE_SIZE).to_a
      raise ArgumentError, "need #{QUEUE_SIZE} queued players, got #{players.size}" unless players.size == QUEUE_SIZE

      persist!(call(players))
    end

    def self.persist!(result)
      ActiveRecord::Base.transaction do
        team_a = build_team!(result.team_a)
        team_b = build_team!(result.team_b)

        Scrim.create!(
          team_a: team_a,
          team_b: team_b,
          captain_a: result.team_a.find(&:captain).player,
          captain_b: result.team_b.find(&:captain).player
        )
      end
    end

    def self.build_team!(assignments)
      team = Team.create!
      assignments.each do |assignment|
        profession = Profession.find_by!(name: assignment.profession_name)
        team.team_players.create!(player: assignment.player, profession: profession, is_captain: assignment.captain)
      end
      team
    end
    private_class_method :build_team!

    def initialize(players)
      @players = players
    end

    def call
      remaining = @players.dup
      team_a = []
      team_b = []

      BUCKETS.each do |flags|
        bucket_players, remaining = remaining.partition { |player| flags.any? { |flag| player.public_send(flag) } }
        draft(bucket_players, team_a, team_b) { |player| profession_name_for(player, flags) }
      end
      draft(remaining, team_a, team_b) { 'None' }

      balance_sizes!(team_a, team_b)
      mark_captain!(team_a)
      mark_captain!(team_b)

      Result.new(team_a: team_a, team_b: team_b)
    end

    private

    def profession_name_for(player, flags)
      matched_flag = flags.find { |flag| player.public_send(flag) }
      FLAG_TO_PROFESSION_NAME.fetch(matched_flag)
    end

    # Each bucket's own snake draft resets to index 0 so it stays fair
    # within that bucket (an elo-sorted foursome always splits 2/2 via
    # A,B,B,A). But a bucket whose size isn't a multiple of 4 leaves a
    # 1-3 player remainder that always leans the same direction - across
    # several buckets those remainders can stack instead of cancelling
    # out. balance_sizes! (below) corrects the total afterward.
    def draft(bucket_players, team_a, team_b)
      grouped_by_elo = bucket_players.group_by { |player| player.elo_rating || DEFAULT_ELO }
      ordered = grouped_by_elo.keys.sort.reverse.flat_map { |elo| grouped_by_elo.fetch(elo).shuffle }

      ordered.each_with_index do |player, index|
        target = SNAKE_PATTERN[index % SNAKE_PATTERN.size] == :a ? team_a : team_b
        target << Assignment.new(player: player, profession_name: yield(player), captain: false)
      end
    end

    # Moves the lowest-elo player off the larger team onto the smaller
    # team, repeatedly, until both are equal size. With 16 total players
    # this always converges on exactly 8-8, and only ever moves the
    # lowest-priority (lowest elo) players from whichever bucket tipped
    # the balance, leaving the snake draft's elo ordering otherwise intact.
    def balance_sizes!(team_a, team_b)
      loop do
        break if team_a.size == team_b.size

        larger, smaller = team_a.size > team_b.size ? [team_a, team_b] : [team_b, team_a]
        outgoing = larger.min_by { |assignment| assignment.player.elo_rating || DEFAULT_ELO }
        larger.delete(outgoing)
        smaller << outgoing
      end
    end

    def mark_captain!(team)
      return if team.empty?

      team.max_by { |assignment| assignment.player.elo_rating || DEFAULT_ELO }.captain = true
    end
  end
end

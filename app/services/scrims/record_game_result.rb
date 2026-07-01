module Scrims
  class RecordGameResult
    WINS_NEEDED = 2

    def self.call!(scrim:, winner:)
      new(scrim, winner).call!
    end

    def initialize(scrim, winner)
      @scrim = scrim
      @winner = winner
    end

    # NOTE: Not safe for concurrent calls on the same scrim - the caller must
    # serialize !win invocations per scrim (e.g. moderator-only gating in the
    # Discord bot) to avoid double-finalizing and double-running calculate_elo!.
    def call!
      raise ArgumentError, 'series is already decided' if @scrim.winner_team_id.present?

      if @winner == :a
        @scrim.increment!(:team_a_wins)
      else
        @scrim.increment!(:team_b_wins)
      end

      finalize! if decided?

      @scrim
    end

    private

    def decided?
      @scrim.team_a_wins >= WINS_NEEDED || @scrim.team_b_wins >= WINS_NEEDED
    end

    def finalize!
      winning_team = @scrim.team_a_wins >= WINS_NEEDED ? @scrim.team_a : @scrim.team_b
      @scrim.update!(winner_team_id: winning_team.id)
      @scrim.calculate_elo!
    end
  end
end

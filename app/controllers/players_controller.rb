class PlayersController < ApplicationController
  def index
    @pagy, @players = pagy(
      Player.with_igname
        .where('elo_rating IS NOT NULL')
        .order(elo_rating: :desc, elo_matches: :desc),
      limit: 18
    )
  end

  def show
    @player = Player.friendly.includes(
      characters: :profession,
      guild: {},
      teams: [
        match: [:tournament],
        team_players: [:character, :player, :profession, :secondary_profession]
      ]
    ).find(params[:id])

    # Paginate player's matches with preloaded data
    @matches_pagy, @matches = pagy(
      @player.teams.includes(
        match: [:tournament, { team_players: [:profession, :secondary_profession] }]
      ).order('matches.played_at DESC'),
      limit: 10
    )
  end
end

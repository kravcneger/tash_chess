class Play::GamesController < Play::BaseController
  def update
    game = @tournament.games.find(params[:id])

    if @participation.report(game, params.expect(game: :result)[:result])
      redirect_to play_tournament_path(@tournament), notice: t(".saved"), status: :see_other
    else
      redirect_to play_tournament_path(@tournament), alert: t(".locked"), status: :see_other
    end
  end
end

class Play::TournamentsController < Play::BaseController
  def show
    @game = @participation.current_game
    @standings = @tournament.standings
  end
end

# Full-screen view for a TV in the playing hall: who plays whom on which board, or the standings, in large type.
# It follows the tournament by itself (current round, live results) and can alternate between both views.
class Tournaments::ScreensController < Tournaments::BaseController
  VIEWS = %w[ pairings standings ].freeze
  ROTATE_INTERVALS = [ 15, 30, 60 ].freeze

  layout "screen"

  def show
    @view = params[:view].presence_in(VIEWS) || (@tournament.finished? ? "standings" : "pairings")
    @rotate = params[:rotate].to_i.presence_in(ROTATE_INTERVALS)
    @theme = params[:theme] == "light" ? "light" : "dark"
    @round = @tournament.current_round
    @standings = @tournament.standings
  end

  private
    def any_browser?
      true
    end
end

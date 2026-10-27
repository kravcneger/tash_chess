module PlayHelper
  def member_color(game, player)
    game.white_player == player ? :white : :black
  end

  # The results a member can enter for their game, as they see it from their side of the board.
  def member_results(color)
    won, lost = color == :white ? %w[ white_won black_won ] : %w[ black_won white_won ]
    { won:, drawn: "draw", lost: }
  end
end

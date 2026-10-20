module ScreensHelper
  # Room for the lists on the TV, in viewport units (what the header, footer and padding leave).
  SCREEN_HEIGHT = 76.0 # vh
  SCREEN_WIDTH = 94.8 # vw
  SCREEN_COLUMN_GAP = 1.6 # vw
  SCREEN_MAX_FONT = 5.4 # vh

  # The current screen URL with some options changed (view, rotation interval, theme).
  def screen_path_with(**changes)
    options = { view: @view, rotate: @rotate, theme: (@theme if @theme == "light") }.merge(changes).compact
    tournament_screen_path(@tournament, options)
  end

  Layout = Data.define(:columns, :rows, :font_height, :font_width) do
    def style
      "--cols: #{columns}; --rows: #{rows}; --fit-h: #{font_height.round(3)}vh; --fit-w: #{font_width.round(3)}vw;"
    end
  end

  # Picks the number of columns for the largest type with every item on one screen of a 16:9 TV, preferring
  # fewer columns when the type is nearly as large. Items are about item_height × item_width em (the block gives
  # the width for a column count, if it depends on it).
  def screen_layout(count, item_height:, item_width: nil, header_rows: 0)
    candidates = (1..4).map do |columns|
      rows = [ (count / columns.to_f).ceil, 1 ].max
      width = item_width || yield(columns)
      font_height = [ SCREEN_HEIGHT / ((rows + header_rows) * item_height), SCREEN_MAX_FONT ].min
      font_width = (SCREEN_WIDTH / columns - SCREEN_COLUMN_GAP) / width
      Layout.new(columns:, rows:, font_height:, font_width:)
    end
    font = ->(layout) { [ layout.font_height, layout.font_width * 16 / 9.0 ].min }
    largest = candidates.map(&font).max
    candidates.find { |layout| font.(layout) >= largest * 0.85 }
  end

  # What each side scored in a finished game: "1" and "0", or "½" twice.
  def screen_score(game, color)
    return unless game.played?

    format_score(game.points_for(color == :white ? game.white_player : game.black_player))
  end

  # A round of the standings: the points scored, colored by the result.
  def screen_standings_cell(cell)
    result, text =
      if cell.nil? then [ "empty", "" ]
      elsif cell.bye? then [ "bye", cell.points.positive? ? "+" : "–" ]
      elsif cell.pending then [ "pending", "…" ]
      else [ { 1.0 => "win", 0.5 => "draw", 0.0 => "loss" }.fetch(cell.points.to_f), format_score(cell.points) ]
      end
    tag.span text, class: "tv-cell tv-cell--#{result}"
  end
end

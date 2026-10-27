module TournamentsHelper
  def tournament_summary(tournament)
    parts = [ tournament.pairing_system_label ]
    parts << rounds_summary(tournament)
    parts << l(tournament.starts_on, format: :long) if tournament.starts_on
    parts << tournament.location if tournament.location
    parts.compact.join(" · ")
  end

  def rounds_summary(tournament)
    if tournament.in_progress? && tournament.current_round
      t("tournaments.summary.round_of", number: tournament.current_round.number, total: tournament.rounds_count)
    elsif tournament.rounds_count
      t("tournaments.summary.rounds", count: tournament.rounds_count)
    elsif tournament.round_robin? && tournament.participations.size > 1
      count = tournament.participations.size
      t("tournaments.summary.all_play_all", rounds: t("tournaments.summary.rounds", count: count.even? ? count - 1 : count))
    end
  end

  # How the game went for one side: :won, :lost or :drawn (nil while it's played, and for a bye).
  def game_outcome(game, color)
    if game.draw?
      :drawn
    elsif game.white_won? || game.black_won?
      game.white_won? == (color == :white) ? :won : :lost
    end
  end

  # "side--won", "side--lost" or "side--drawn", to color a player's side of a game.
  def outcome_class(game, color, prefix: "side")
    outcome = game_outcome(game, color)
    "#{prefix}--#{outcome}" if outcome
  end

  # Gold, silver and bronze for the top three once somebody has scored.
  def podium_class(row)
    medal = { 1 => "gold", 2 => "silver", 3 => "bronze" }[row.rank]
    "standing--podium standing--#{medal}" if medal && row.points.positive?
  end

  def withdrawn_badge
    tag.span t("tournaments.withdrawn"), class: "badge badge--withdrawn"
  end

  def standings_cell(cell)
    return tag.span("", class: "cell cell--empty") if cell.nil?

    if cell.bye?
      bye = cell.points.positive?
      tag.span(bye ? "+" : "–", class: "cell cell--bye", title: t(bye ? "standings_cell.bye" : "standings_cell.rested"))
    elsif cell.pending
      tag.span("…", class: "cell cell--pending", title: t("standings_cell.pending", opponent: cell.opponent.name, color: t("colors.with.#{cell.color}")))
    else
      result = { 1.0 => "win", 0.5 => "draw", 0.0 => "loss" }.fetch(cell.points.to_f)
      title = t("standings_cell.#{result}", opponent: cell.opponent.name, color: t("colors.with.#{cell.color}"))
      tag.span(class: "cell cell--#{result}", title:) do
        safe_join([ piece_color(cell.color), format_score(cell.points) ])
      end
    end
  end

  # The QR code a member scans to sign in, as inline SVG. Always dark on white with the standard quiet zone of
  # 4 modules around it, whatever the theme: phone cameras need the contrast.
  def qr_code(url)
    qr = RQRCode::QRCode.new(url, level: :m)
    size = qr.qrcode.module_count + 8
    modules = qr.as_svg(standalone: false, use_path: true, module_size: 1, offset: 4, fill: "fff", color: "000")
    tag.svg modules.html_safe, class: "qr", viewBox: "0 0 #{size} #{size}", "shape-rendering": "crispEdges", aria: { hidden: true }
  end
end

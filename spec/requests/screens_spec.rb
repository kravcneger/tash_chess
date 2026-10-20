require "rails_helper"

RSpec.describe "Hall screen" do
  let(:tournament) { create_tournament(players: Player.by_rating.first(5), rounds: 3) }

  it "lists the members while registration is open" do
    get tournament_screen_path(tournament)

    expect(response).to have_http_status(:success)
    expect(texts(".tv-member .tv-name")).to eq(Player.by_rating.first(5).map(&:name))
  end

  it "shows who plays whom in the current round, with results" do
    tournament.start
    play_round(tournament.current_round)
    tournament.pair_next_round
    game = tournament.current_round.games.reject(&:bye?).first
    game.update!(result: :white_won)

    get tournament_screen_path(tournament)

    expect(texts(".tv-round__number")).to eq([ "2" ])
    expect(texts(".tv-game .tv-board")).to eq([ "1", "2", "—" ])
    card = page_html.at_css("#screen_game_#{game.id}")
    expect(card.css(".tv-name").map(&:text)).to eq([ game.white_player.name, game.black_player.name ])
    expect(card.css(".tv-result").map(&:text)).to eq(%w[ 1 0 ])
    expect(card.css(".tv-side").map { |side| side["class"][/tv-side--(won|lost)/] }).to eq(%w[ tv-side--won tv-side--lost ])
    expect(texts(".tv-side--bye")).to eq([ I18n.t("tournaments.screens.pairings.bye", points: 1) ])
  end

  it "shows the standings, by default once the tournament is finished" do
    tournament.start
    3.times do |index|
      play_round(tournament.current_round)
      tournament.pair_next_round unless index == 2
    end

    get tournament_screen_path(tournament, view: "standings")
    expect(page_html.css(".tv-standing:not(.tv-standing--head)").size).to eq(5)

    tournament.finish
    get tournament_screen_path(tournament)
    expect(page_html.css(".tv-standing:not(.tv-standing--head)").size).to eq(5)
    expect(page_html.css(".tv-live")).to be_empty
  end

  it "keeps the options when switching views" do
    get tournament_screen_path(tournament, view: "standings", rotate: 30, theme: "light")

    expect(page_html.at_css("body")["class"]).to include("tv--light")
    expect(page_html.at_css("body")["data-screen-rotate-value"]).to eq("30")
    expect(page_html.at_css("body")["data-screen-next-url-value"]).to eq(tournament_screen_path(tournament, view: "pairings", rotate: 30, theme: "light"))
  end

  it "opens in old TV browsers" do
    get tournament_screen_path(tournament), headers: { "User-Agent" => "Mozilla/5.0 (SMART-TV; Linux; Tizen 5.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.106 Safari/537.36" }
    expect(response).to have_http_status(:success)

    get tournament_path(tournament), headers: { "User-Agent" => "Mozilla/5.0 (SMART-TV; Linux; Tizen 5.0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.106 Safari/537.36" }
    expect(response).to have_http_status(:not_acceptable)
  end
end

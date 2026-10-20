require "rails_helper"

RSpec.describe "Locales" do
  it "shows pages in Russian by default" do
    get root_path

    expect(page_lang).to eq("ru")
    expect(texts("h1")).to eq([ "Турниры" ])
  end

  it "switches to English and back" do
    patch locale_path, params: { locale: "en" }, headers: { "HTTP_REFERER" => players_url }
    expect(response).to redirect_to(players_url)

    get root_path
    expect(page_lang).to eq("en")
    expect(texts("h1")).to eq([ "Tournaments" ])

    patch locale_path, params: { locale: "ru" }
    get root_path
    expect(page_lang).to eq("ru")
  end

  it "ignores unknown languages" do
    patch locale_path, params: { locale: "xx" }
    get root_path

    expect(page_lang).to eq("ru")
  end

  # Missing translations raise in tests, so rendering every screen in every language checks both locale files.
  describe "every page" do
    let(:paths) do
      registration = create_tournament(players: Player.by_rating.first(5), rounds: 3)
      swiss = create_tournament(players: Player.by_rating.first(5), rounds: 2)
      swiss.start
      play_round(swiss.current_round)
      swiss.pair_next_round
      swiss.withdraw(swiss.participations.find_by!(player: players(:anna)))
      finished = create_tournament(system: :round_robin, rounds: nil, players: Player.by_rating.first(3))
      finished.start
      finished.rounds.each { |round| play_round(round) { :draw } }
      finished.finish
      round_robin = create_tournament(system: :round_robin, rounds: 6, players: Player.by_rating.first(4))
      round_robin.start

      [
        root_path, new_tournament_path, players_path, players_path(query: "zzz"), new_player_path(tournament_id: registration.id),
        player_path(players(:anna)), edit_player_path(players(:anna)),
        tournament_path(registration), edit_tournament_path(registration), tournament_standings_path(registration),
        tournament_path(swiss), edit_tournament_path(swiss), tournament_round_path(swiss, 1), tournament_round_path(swiss, 2),
        tournament_standings_path(swiss),
        tournament_path(finished), tournament_round_path(finished, 1), tournament_standings_path(finished),
        tournament_path(round_robin), edit_tournament_path(round_robin), tournament_round_path(round_robin, 6),
        tournament_standings_path(round_robin),
        tournament_screen_path(registration), tournament_screen_path(swiss), tournament_screen_path(swiss, view: "standings"),
        tournament_screen_path(finished), tournament_screen_path(finished, view: "pairings"), tournament_screen_path(round_robin)
      ]
    end

    I18n.available_locales.each do |locale|
      it "renders in #{locale}" do
        cookies[:locale] = locale.to_s

        paths.each do |path|
          get path
          expect(response).to have_http_status(:success), "#{path} failed in #{locale}"
          expect(page_lang).to eq(locale.to_s)
        end
      end
    end
  end
end

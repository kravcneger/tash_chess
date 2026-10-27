require "rails_helper"

RSpec.describe "Members on their phones" do
  let(:tournament) { create_tournament(players: Player.by_rating.first(5), rounds: 3) }
  let(:participation) { tournament.participations.find_by!(player: players(:anna)) }

  def join(participation)
    get join_path(participation.access_token)
  end

  describe "the arbiter's QR codes" do
    it "shows a member's code with the way to the next one" do
      members = tournament.participations.joins(:player).merge(Player.by_rating).to_a

      get tournament_path(tournament)
      expect(page_html.css("a[href='#{tournament_participation_path(tournament, members.first)}'] svg")).to be_present

      get tournament_participation_path(tournament, members.second)
      expect(response).to have_http_status(:success)
      expect(page_html.css("svg.qr path")).to be_present
      expect(texts(".pass__url")).to eq([ join_url(members.second.access_token) ])
      expect(texts(".pass__nav a")).to eq([ members.first.player.name, members.third.player.name ])
    end

    it "shows them in a finished tournament too" do
      tournament.start
      tournament.update!(status: :finished)

      get tournament_participation_path(tournament, participation)
      expect(response).to have_http_status(:success)
    end
  end

  it "signs a member in with their QR code" do
    join(participation)
    expect(response).to redirect_to(play_tournament_path(tournament))
    expect(flash[:notice]).to eq(I18n.t("play.sessions.create.signed_in", name: players(:anna).name))

    follow_redirect!
    expect(response).to have_http_status(:success)
    expect(texts(".play-head__who strong")).to eq([ players(:anna).name ])
    expect(texts("h2")).to include(I18n.t("play.tournaments.show.not_started"))
    expect(page_html.css(".table--standings tbody tr").size).to eq(5)
    expect(texts(".standing--me .strong-link")).to eq([ players(:anna).name ])
    expect(page_html.css("main a")).to be_empty, "no links to the arbiter's pages"
  end

  it "asks for the QR code without it" do
    get play_tournament_path(tournament)

    expect(response).to have_http_status(:unauthorized)
    expect(texts("h1")).to eq([ I18n.t("play.sessions.new.title") ])
    expect(texts(".play-signin p")).to eq([ I18n.t("play.sessions.new.scan") ])
  end

  it "refuses an unknown code" do
    get join_path("not-a-code")

    expect(response).to have_http_status(:not_found)
    expect(texts(".play-signin p")).to eq([ I18n.t("play.sessions.new.invalid") ])
  end

  it "stops working once the member is removed from the tournament" do
    join(participation)
    tournament.unenroll(participation)

    get play_tournament_path(tournament)
    expect(response).to have_http_status(:unauthorized)
  end

  it "signs in to one tournament per code, keeping the others" do
    other = create_tournament(players: Player.by_rating.first(2), rounds: 1)

    join(participation)
    get play_tournament_path(other)
    expect(response).to have_http_status(:unauthorized)

    join(other.participations.first)
    get play_tournament_path(tournament)
    expect(response).to have_http_status(:success)
  end

  it "signs out" do
    join(participation)

    delete play_session_path(tournament)
    expect(response).to redirect_to(play_tournament_path(tournament))
    expect(flash[:notice]).to eq(I18n.t("play.sessions.destroy.signed_out"))

    follow_redirect!
    expect(response).to have_http_status(:unauthorized)
  end

  describe "entering a result" do
    before { tournament.start }

    let(:game) { participation.current_game }

    it "takes the member's result once, from their side of the board" do
      join(participation)
      get play_tournament_path(tournament)

      expect(texts(".my-game__board")).to eq([ I18n.t("tournaments.rounds.show.board_number", number: game.board) ])
      expect(texts(".my-game__side--me .my-game__name")).to eq([ "#{players(:anna).name} #{I18n.t("play.tournaments.show.you_mark")}" ])
      won, lost = game.white_player == players(:anna) ? %w[ white_won black_won ] : %w[ black_won white_won ]
      choices = page_html.css(".outcomes form").map { |form| form.at_css("input[name='game[result]']")["value"] }
      expect(choices).to eq([ won, "draw", lost ])

      patch play_game_path(tournament, game), params: { game: { result: won } }
      expect(response).to redirect_to(play_tournament_path(tournament))
      expect(flash[:notice]).to eq(I18n.t("play.games.update.saved"))
      expect(game.reload.result).to eq(won)

      follow_redirect!
      expect(page_html.css(".outcomes")).to be_empty
      expect(texts(".my-game__result .badge")).to eq([ I18n.t("play.tournaments.show.outcomes.won") ])

      patch play_game_path(tournament, game), params: { game: { result: "draw" } }
      expect(flash[:alert]).to eq(I18n.t("play.games.update.locked"))
      expect(game.reload.result).to eq(won), "a result that is in is the arbiter's to change"
    end

    it "lets the opponent see it live" do
      opponent = tournament.participations.find_by!(player: game.players.excluding(players(:anna)).first)
      join(opponent)
      patch play_game_path(tournament, game), params: { game: { result: "draw" } }

      follow_redirect!
      expect(texts(".my-game__result .badge")).to eq([ I18n.t("play.tournaments.show.outcomes.drawn") ])
    end

    it "doesn't touch other games" do
      other_game = tournament.current_round.games.reject(&:bye?).find { |g| g != game }
      join(participation)

      patch play_game_path(tournament, other_game), params: { game: { result: "draw" } }
      expect(flash[:alert]).to eq(I18n.t("play.games.update.locked"))
      expect(other_game.reload).to be_pending

      patch play_game_path(tournament, game), params: { game: { result: "pending" } }
      expect(flash[:alert]).to eq(I18n.t("play.games.update.locked"))

      elsewhere = create_tournament(players: Player.by_rating.first(2), rounds: 1).tap(&:start).games.first
      patch play_game_path(tournament, elsewhere), params: { game: { result: "draw" } }
      expect(response).to have_http_status(:not_found)
      expect(elsewhere.reload).to be_pending
    end

    it "needs the member signed in" do
      patch play_game_path(tournament, game), params: { game: { result: "draw" } }

      expect(response).to have_http_status(:unauthorized)
      expect(game.reload).to be_pending
    end

    it "tells a member with a bye, and one who withdrew" do
      join(tournament.participations.find_by!(player: players(:erik)))
      get play_tournament_path(tournament)
      expect(texts(".my-game p")).to eq([ I18n.t("play.tournaments.show.bye", points: 1) ])

      tournament.withdraw(participation)
      join(participation)
      get play_tournament_path(tournament)
      expect(texts(".my-game h2")).to eq([ I18n.t("play.tournaments.show.withdrawn") ])
    end

    it "shows only the final standings once the tournament is finished" do
      3.times do |index|
        play_round(tournament.current_round)
        tournament.pair_next_round unless index == 2
      end
      tournament.finish
      join(participation)

      get play_tournament_path(tournament)
      expect(page_html.css(".my-game")).to be_empty
      expect(texts("h2")).to eq([ I18n.t("tournaments.standings.show.final") ])
    end
  end
end

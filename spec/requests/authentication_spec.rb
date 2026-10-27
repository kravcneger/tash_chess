require "rails_helper"

RSpec.describe "Authentication" do
  def login(name, password)
    { "HTTP_AUTHORIZATION" => ActionController::HttpAuthentication::Basic.encode_credentials(name, password) }
  end

  def stub_login(name, password)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("BASIC_AUTH_USERNAME").and_return(name)
    allow(ENV).to receive(:[]).with("BASIC_AUTH_PASSWORD").and_return(password)
  end

  context "with a login set" do
    before { stub_login("arbiter", "secret") }

    it "asks for it" do
      get root_path

      expect(response).to have_http_status(:unauthorized)
      expect(response.headers["WWW-Authenticate"]).to eq(%(Basic realm="Tash Chess"))
      expect(response.body).to eq("Нужны логин и пароль.")
    end

    it "refuses a wrong username or password" do
      get root_path, headers: login("arbiter", "wrong")
      expect(response).to have_http_status(:unauthorized)

      get root_path, headers: login("someone", "secret")
      expect(response).to have_http_status(:unauthorized)
    end

    it "lets the right login in" do
      get root_path, headers: login("arbiter", "secret")
      expect(response).to have_http_status(:success)

      post players_path, params: { player: { name: "Magnus Test", nickname: "magnus" } }, headers: login("arbiter", "secret")
      expect(response).to redirect_to(player_path(Player.find_by!(nickname: "magnus")))
    end

    it "explains in the chosen language" do
      cookies[:locale] = "en"
      get root_path

      expect(response.body).to eq("A username and password are required.")
    end

    it "keeps the health check open" do
      get rails_health_check_path
      expect(response).to have_http_status(:success)
    end

    it "lets members in with their QR code instead, to their tournament only" do
      tournament = create_tournament(players: Player.by_rating.first(2), rounds: 1)
      participation = tournament.participations.first

      get tournament_participation_path(tournament, participation)
      expect(response).to have_http_status(:unauthorized), "the codes are for the arbiter to show"

      get join_path(participation.access_token)
      expect(response).to redirect_to(play_tournament_path(tournament))
      follow_redirect!
      expect(response).to have_http_status(:success)

      patch locale_path, params: { locale: "en" }
      expect(response).to have_http_status(:see_other)

      get tournament_path(tournament)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "stays open without a login set, in production too" do
    allow(Rails.env).to receive(:production?).and_return(true)

    stub_login(nil, nil)
    get root_path
    expect(response).to have_http_status(:success)

    stub_login("arbiter", "")
    get root_path
    expect(response).to have_http_status(:success)
  end
end

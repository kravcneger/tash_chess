require "rails_helper"

RSpec.describe "Countdown to the next round" do
  include ActiveSupport::Testing::TimeHelpers

  let(:tournament) { create_tournament(players: Player.by_rating.first(4), rounds: 3).tap(&:start) }
  let(:participation) { tournament.participations.find_by!(player: players(:anna)) }

  it "is started by the arbiter and counted down on the members' phones" do
    freeze_time do
      post tournament_countdown_path(tournament), params: { minutes: "5" }, headers: { "HTTP_REFERER" => tournament_standings_url(tournament) }
      expect(response).to redirect_to(tournament_standings_url(tournament))
      expect(flash[:notice]).to eq(I18n.t("tournaments.countdowns.create.started", count: 5))

      follow_redirect!
      expect(page_html.at_css(".countdown-badge")["data-countdown-seconds-value"]).to eq("300")
      expect(texts(".countdown-badge")).to eq([ "5:00" ])

      get join_path(participation.access_token)
      follow_redirect!
      countdown = page_html.at_css(".countdown")
      expect(countdown["data-countdown-seconds-value"]).to eq("300")
      expect(countdown.at_css(".countdown__time").text).to eq("5:00")
      expect(countdown.at_css(".countdown__label").text).to eq(I18n.t("play.tournaments.show.countdown"))
    end
  end

  it "shows the time left, and nothing once it's over" do
    get join_path(participation.access_token)

    freeze_time do
      tournament.update!(next_round_starts_at: 90.seconds.from_now)
      get play_tournament_path(tournament)
      expect(texts(".countdown__time")).to eq([ "1:30" ])
    end

    travel 2.minutes
    get play_tournament_path(tournament)
    expect(page_html.css(".countdown")).to be_empty

    get tournament_path(tournament)
    expect(page_html.css(".countdown-badge")).to be_empty
  end

  it "can be cancelled" do
    tournament.start_countdown(10)

    get tournament_path(tournament)
    expect(texts(".menu__item--danger")).to include(I18n.t("tournaments.header.countdown_cancel"))

    delete tournament_countdown_path(tournament)
    expect(response).to redirect_to(tournament_path(tournament))
    expect(flash[:notice]).to eq(I18n.t("tournaments.countdowns.destroy.cancelled"))
    expect(tournament.reload.next_round_starts_at).to be_nil

    get join_path(participation.access_token)
    follow_redirect!
    expect(page_html.css(".countdown")).to be_empty
  end

  it "explains a wrong number of minutes" do
    post tournament_countdown_path(tournament), params: { minutes: "500" }

    expect(flash[:alert]).to eq(I18n.t("activerecord.errors.models.tournament.attributes.base.countdown_minutes", max: 120))
    expect(tournament.reload.next_round_starts_at).to be_nil
  end

  it "isn't offered once the tournament is finished" do
    3.times do |index|
      play_round(tournament.current_round)
      tournament.pair_next_round unless index == 2
    end
    tournament.finish

    get tournament_path(tournament)
    expect(page_html.css("form[action='#{tournament_countdown_path(tournament)}']")).to be_empty

    post tournament_countdown_path(tournament), params: { minutes: "5" }
    expect(flash[:alert]).to eq(I18n.t("activerecord.errors.models.tournament.attributes.base.countdown_finished"))
  end
end

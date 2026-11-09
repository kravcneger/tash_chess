require "rails_helper"

RSpec.describe "Players" do
  it "lists and searches players" do
    get players_path
    expect(response).to have_http_status(:success)
    expect(texts("td")).to include("Anna Kowalska")

    get players_path(query: "chen")
    expect(texts("td a")).to include("Chen Wei")
    expect(texts("td a")).not_to include("Anna Kowalska")
  end

  it "creates a player" do
    expect {
      post players_path, params: { player: { name: "Magnus Test", nickname: "magnus", fide_rating: "2500", telegram: "@magnus_t" } }
    }.to change(Player, :count).by(1)

    player = Player.find_by!(nickname: "magnus")
    expect(response).to redirect_to(player_path(player))
    expect(player.fide_rating).to eq(2500)
    expect(player.telegram).to eq("magnus_t")
  end

  it "shows the arbiter the player's Telegram" do
    get player_path(players(:anna))
    expect(page_html.css("a[href='https://t.me/anna_kowalska']").map(&:text)).to eq([ "Telegram @anna_kowalska" ])

    get player_path(players(:hana))
    expect(page_html.css("a[href^='https://t.me/']")).to be_empty
  end

  it "creates a player without a rating straight into a tournament" do
    tournament = create_tournament(players: [])

    post players_path, params: { tournament_id: tournament.id, player: { name: "Walk In", nickname: "walkin", fide_rating: "" } }

    expect(response).to redirect_to(tournament_path(tournament))
    expect(tournament.players.reload.pluck(:nickname)).to eq([ "walkin" ])
    expect(Player.find_by!(nickname: "walkin").fide_rating).to be_nil
  end

  it "rejects a duplicate nickname" do
    expect {
      post players_path, params: { player: { name: "Other Anna", nickname: "Anna_K" } }
    }.not_to change(Player, :count)

    expect(response).to have_http_status(:unprocessable_content)
    expect(texts(".form-errors li")).to include("#{Player.human_attribute_name(:nickname)} #{I18n.t("errors.messages.taken")}")
  end

  it "updates a player" do
    patch player_path(players(:hana)), params: { player: { fide_rating: "1650" } }

    expect(response).to redirect_to(player_path(players(:hana)))
    expect(players(:hana).reload.fide_rating).to eq(1650)
  end

  it "deletes a player" do
    expect { delete player_path(players(:hana)) }.to change(Player, :count).by(-1)
    expect(response).to redirect_to(players_path)
  end

  it "refuses to delete a player with games" do
    create_tournament(players: [ players(:anna), players(:boris) ], rounds: 1).start

    expect { delete player_path(players(:anna)) }.not_to change(Player, :count)
    expect(response).to redirect_to(player_path(players(:anna)))
    expect(flash[:alert]).to eq(I18n.t("activerecord.errors.models.player.attributes.base.games_played", name: players(:anna).name))
  end
end

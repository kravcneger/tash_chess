require "rails_helper"

RSpec.describe Player do
  it "is valid without a FIDE rating" do
    expect(Player.new(name: "New Player", nickname: "newbie")).to be_valid
  end

  it "requires a name and a nickname" do
    player = Player.new

    expect(player).not_to be_valid
    expect(player.errors).to be_of_kind(:name, :blank)
    expect(player.errors).to be_of_kind(:nickname, :blank)
  end

  describe "nickname" do
    it "is unique regardless of case and surrounding spaces" do
      player = Player.new(name: "Copycat", nickname: "  ANNA_K ")

      expect(player).not_to be_valid
      expect(player.errors).to be_of_kind(:nickname, :taken)
    end

    it "is unique in the database too" do
      expect { Player.new(name: "Copycat", nickname: "Boris").save!(validate: false) }
        .to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "can't contain spaces" do
      player = Player.new(name: "Spacey", nickname: "two words")

      expect(player).not_to be_valid
      expect(player.errors).to be_of_kind(:nickname, :invalid)
    end
  end

  it "accepts only realistic FIDE ratings" do
    expect(Player.new(name: "Low", nickname: "low", fide_rating: 400)).not_to be_valid
    expect(Player.new(name: "High", nickname: "high", fide_rating: 3500)).not_to be_valid
    expect(Player.new(name: "Okay", nickname: "okay", fide_rating: 1400)).to be_valid
  end

  describe "telegram" do
    it "keeps just the username, however it's typed in" do
      [ "anna_t", " @anna_t ", "https://t.me/anna_t", "t.me/anna_t" ].each do |typed|
        expect(Player.new(telegram: typed).telegram).to eq("anna_t"), "from #{typed.inspect}"
      end
    end

    it "is optional" do
      player = Player.new(name: "New Player", nickname: "newbie", telegram: " ")

      expect(player).to be_valid
      expect(player.telegram).to be_nil
    end

    it "must be a Telegram username" do
      player = Player.new(name: "New Player", nickname: "newbie", telegram: "+7 999 123-45-67")

      expect(player).not_to be_valid
      expect(player.errors).to be_of_kind(:telegram, :invalid)
    end
  end

  describe ".search" do
    it "matches the name or nickname case-insensitively" do
      expect(Player.search("KOWAL")).to contain_exactly(players(:anna))
      expect(Player.search("chenw")).to contain_exactly(players(:chen))
    end
  end

  describe "#destroy" do
    it "removes a player who is only registered in a tournament" do
      tournament = create_tournament(players: [ players(:anna), players(:boris) ])

      expect { players(:anna).destroy! }
        .to change(Player, :count).by(-1)
        .and change { tournament.participations.count }.by(-1)
    end

    it "refuses once the player has played games" do
      create_tournament(players: [ players(:anna), players(:boris) ], rounds: 1).start
      player = players(:anna)

      expect(player.destroy).to be(false)
      expect(Player).to exist(player.id)
      expect(player.errors).to be_of_kind(:base, :games_played)
    end
  end
end

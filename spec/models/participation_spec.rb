require "rails_helper"

RSpec.describe Participation do
  let(:tournament) { create_tournament(players: Player.by_rating.first(5), rounds: 3) }

  def member(player)
    tournament.participations.find_by!(player:)
  end

  it "gets its own sign-in code" do
    codes = tournament.participations.map(&:access_token)

    expect(codes).to all(match(/\A[A-Za-z0-9]{24}\z/))
    expect(codes.uniq.size).to eq(5)
  end

  describe "#current_game" do
    it "is the game of the round being played, a bye too" do
      expect(member(players(:anna)).current_game).to be_nil

      tournament.start
      round = tournament.current_round
      expect(member(players(:anna)).current_game).to eq(round.games.merge(players(:anna).games).first)
      expect(member(players(:erik)).current_game).to be_bye

      play_round(round)
      tournament.pair_next_round
      expect(member(players(:anna)).current_game.round.number).to eq(2)
    end

    it "follows the round being played in a round robin" do
      tournament = create_tournament(system: :round_robin, rounds: nil, players: Player.by_rating.first(4))
      tournament.start
      participation = tournament.participations.find_by!(player: players(:anna))

      expect(participation.current_game.round.number).to eq(1)
      play_round(tournament.rounds.first)
      expect(participation.current_game.round.number).to eq(2)
    end
  end

  describe "#report" do
    before { tournament.start }

    let(:participation) { member(players(:anna)) }
    let(:game) { participation.current_game }

    it "enters the result of the member's game" do
      expect(participation.report(game, "draw")).to be(true)
      expect(game.reload).to be_draw
    end

    it "takes the first result in only" do
      Game.find(game.id).update!(result: :white_won)

      expect(participation.report(game, "black_won")).to be(false)
      expect(game.reload).to be_white_won
    end

    it "refuses other games, clearing a result and a bye" do
      other_game = tournament.current_round.games.reject(&:bye?).find { |g| g != game }
      expect(participation.report(other_game, "draw")).to be(false)
      expect(other_game.reload).to be_pending

      expect(participation.report(game, "pending")).to be(false)
      expect(participation.report(game, "bye")).to be(false)
      expect(game.reload).to be_pending

      bye = member(players(:erik)).current_game
      expect(member(players(:erik)).report(bye, "white_won")).to be(false)
      expect(bye.reload).to be_bye
    end

    it "refuses games of earlier rounds" do
      first_game = game
      play_round(tournament.current_round)
      tournament.pair_next_round
      first_game.reload.update!(result: :pending) # cleared by the arbiter

      expect(participation.report(first_game, "draw")).to be(false)
      expect(first_game.reload).to be_pending
    end

    it "refuses once the tournament is finished" do
      tournament.update!(status: :finished)

      expect(participation.report(game, "draw")).to be(false)
    end
  end
end

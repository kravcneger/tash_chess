require "rails_helper"

RSpec.describe Tournament do
  let(:four_players) { Player.by_rating.first(4) }

  it "needs a number of rounds for Swiss but not for round robin" do
    expect(Tournament.new(name: "Swiss", pairing_system: :swiss)).not_to be_valid
    expect(Tournament.new(name: "RR", pairing_system: :round_robin)).to be_valid
  end

  describe "#start" do
    it "needs at least two members" do
      tournament = create_tournament(players: [ players(:anna) ])

      expect(tournament.start).to be(false)
      expect(tournament.reload).to be_registration
      expect(tournament.errors).to be_of_kind(:base, :not_enough_members)
    end

    it "accepts more Swiss rounds than there are opponents" do
      tournament = create_tournament(players: four_players, rounds: 10)

      expect(tournament.start).to be(true)
    end

    it "plays one full round robin cycle when the number of rounds is blank" do
      tournament = create_tournament(system: :round_robin, rounds: nil, players: Player.by_rating.first(5))
      tournament.start

      expect(tournament.rounds_count).to eq(5)
    end

    it "locks the pairing system" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start

      expect(tournament.update(pairing_system: :round_robin)).to be(false)
    end

    it "lets players join a running Swiss for the next round" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start
      tournament.enroll([ players(:hana) ])

      expect(tournament.current_round.games.flat_map(&:players)).not_to include(players(:hana))
      play_round(tournament.current_round)
      tournament.pair_next_round
      expect(tournament.current_round.games.flat_map(&:players)).to include(players(:hana))
    end

    it "keeps members with games from leaving" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start

      expect(tournament.participations.first.destroy).to be(false)
    end
  end

  describe "#pair_next_round" do
    it "needs every result of the current round" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start

      expect(tournament.pair_next_round).to be(false)
      play_round(tournament.current_round)
      expect(tournament.pair_next_round).to be(true)
      expect(tournament.rounds.count).to eq(2)
    end

    it "stops at the planned number of rounds, then the tournament can finish" do
      tournament = create_tournament(players: four_players, rounds: 1)
      tournament.start
      play_round(tournament.current_round)

      expect(tournament.can_pair_next_round?).to be(false)
      expect(tournament.finish).to be(true)
      expect(tournament.reload).to be_finished
    end
  end

  describe "#withdraw" do
    def membership(tournament, player)
      tournament.participations.find_by!(player:)
    end

    def players_in(rounds)
      Array(rounds).flat_map { |round| round.games.reload.flat_map(&:players) }
    end

    it "scores a Swiss game still in play as a loss and pairs nobody against the player again" do
      tournament = create_tournament(players: Player.by_rating.first(6), rounds: 3)
      tournament.start
      leaver = players(:anna)
      game = tournament.current_round.games.find { |game| game.players.include?(leaver) }
      opponent = (game.players - [ leaver ]).first
      tournament.current_round.games.excluding(game).each { |other| other.update!(result: :draw) }

      expect(tournament.withdraw(membership(tournament, leaver))).to be(true)
      expect(game.reload.points_for(opponent)).to eq(1.0)

      2.times do
        expect(tournament.pair_next_round).to be(true)
        expect(players_in(tournament.current_round)).not_to include(leaver)
        expect(players_in(tournament.current_round).uniq.size).to eq(5), "the others all play, one with a bye"
        play_round(tournament.current_round)
      end

      expect(tournament.standings[leaver]).to have_attributes(points: 0.0, losses: 1)
      expect(tournament.standings.withdrawn?(leaver)).to be(true)
    end

    it "keeps counting the games against the player when pairing the others" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start
      leaver = players(:daria)
      game = tournament.current_round.games.find { |game| game.players.include?(leaver) }
      winner = (game.players - [ leaver ]).first
      tournament.current_round.games.excluding(game).each { |other| other.update!(result: :draw) }
      tournament.withdraw(membership(tournament, leaver))

      tournament.pair_next_round

      expect(tournament.current_round.games.first.players).to include(winner), "the forfeit win puts them on top"
      expect(tournament.current_round.games.find(&:bye?).white_player).not_to eq(winner)
    end

    it "pairs the round robin rounds that haven't started again without the player" do
      tournament = create_tournament(system: :round_robin, rounds: nil, players: Player.by_rating.first(6))
      tournament.start
      play_round(tournament.rounds.first)
      leaver = players(:anna)
      round_two = tournament.rounds.second
      game = round_two.games.find { |game| game.players.include?(leaver) }
      pairings = round_two.games.map { |game| [ game.white_player_id, game.black_player_id ] }
      round_two.games.excluding(game).each { |other| other.update!(result: :draw) }

      expect(tournament.withdraw(membership(tournament, leaver))).to be(true)

      expect(game.reload).not_to be_pending
      expect(round_two.games.reload.map { |game| [ game.white_player_id, game.black_player_id ] }).to eq(pairings)
      expect(tournament.current_round.number).to eq(3), "the forfeit completed round 2"
      expect(tournament.rounds.count).to eq(5)
      later = tournament.rounds.drop(2)
      expect(players_in(later)).not_to include(leaver)
      expect(later.map { |round| round.games.count(&:bye?) }).to all(eq(1)), "with five players left, one rests"
    end

    it "lets a Swiss finish when fewer than two players are left" do
      tournament = create_tournament(players: Player.by_rating.first(2), rounds: 3)
      tournament.start
      tournament.withdraw(tournament.participations.first)

      expect(tournament.can_pair_next_round?).to be(false)
      expect(tournament.finish).to be(true)
    end

    it "is only for members still playing in a running tournament" do
      tournament = create_tournament(players: four_players, rounds: 3)
      participation = tournament.participations.first

      expect(tournament.withdraw(participation)).to be(false)
      expect(tournament.errors).to be_of_kind(:base, :cannot_withdraw)
      tournament.errors.clear
      tournament.start
      expect(tournament.withdraw(participation)).to be(true)
      expect(tournament.withdraw(participation)).to be(false), "already withdrawn"
    end

    it "drops withdrawn members when the start is undone" do
      tournament = create_tournament(players: Player.by_rating.first(3), rounds: 3)
      tournament.start
      resting = tournament.current_round.games.find(&:bye?).white_player
      tournament.withdraw(membership(tournament, resting))

      expect(tournament.reset).to be_truthy
      expect(tournament.players.reload).not_to include(resting)
    end
  end

  describe "#reinstate" do
    it "pairs the player again from the next Swiss round" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start
      participation = tournament.participations.find_by!(player: players(:daria))
      tournament.withdraw(participation)
      play_round(tournament.current_round)
      tournament.pair_next_round

      expect(tournament.reinstate(participation)).to be(true)
      expect(tournament.reinstate(participation)).to be(false), "already back"
      play_round(tournament.current_round)
      tournament.pair_next_round
      expect(tournament.current_round.games.flat_map(&:players)).to include(players(:daria))
    end

    it "restores the round robin plan when nothing was played in between" do
      tournament = create_tournament(system: :round_robin, rounds: nil, players: four_players)
      tournament.start
      plan = tournament.rounds.map { |round| round.games.map { |game| [ game.white_player_id, game.black_player_id ] } }
      participation = tournament.participations.find_by!(player: players(:anna))

      tournament.withdraw(participation)
      expect(tournament.rounds.drop(1).flat_map { |round| round.games.flat_map(&:players) }).not_to include(players(:anna))

      tournament.reinstate(participation)
      rounds = tournament.rounds.reload.map { |round| round.games.map { |game| [ game.white_player_id, game.black_player_id ] } }
      expect(rounds).to eq(plan)
    end
  end

  describe "#reset" do
    it "removes pairings only before any result" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start
      game = tournament.current_round.games.first
      expect(tournament.can_reset?).to be(true)

      game.update!(result: :draw)
      expect(tournament.reset).to be(false)

      game.update!(result: :pending)
      expect(tournament.reset).to be_truthy
      expect(tournament.reload).to be_registration
      expect(tournament.rounds.count).to eq(0)
    end
  end

  describe "#remove_last_round" do
    it "returns to registration when the only round is deleted" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start

      expect(tournament.remove_last_round).to be_truthy
      expect(tournament.reload).to be_registration
    end
  end

  describe "#destroy" do
    it "deletes a tournament with results but keeps the players" do
      tournament = create_tournament(players: four_players, rounds: 3)
      tournament.start
      play_round(tournament.current_round)

      expect { tournament.destroy! }
        .to change(Tournament, :count).by(-1)
        .and change(Game, :count).by(-2)
        .and change(Participation, :count).by(-4)
        .and(not_change(Player, :count))
    end
  end

  describe "#start_countdown" do
    include ActiveSupport::Testing::TimeHelpers

    let(:tournament) { create_tournament(players: four_players, rounds: 3) }

    it "sets when the next round starts, until then" do
      freeze_time do
        expect(tournament.start_countdown("5")).to be(true)
        expect(tournament.reload.next_round_starts_at).to eq(5.minutes.from_now)
        expect(tournament).to be_countdown_running
      end

      travel 6.minutes
      expect(tournament).not_to be_countdown_running
    end

    it "takes 1 to 120 minutes" do
      [ "0", "121", "2.5", "five", "", nil ].each do |minutes|
        expect(tournament.start_countdown(minutes)).to be(false), minutes.inspect
      end
      expect(tournament.errors).to be_of_kind(:base, :countdown_minutes)
      expect(tournament.reload.next_round_starts_at).to be_nil

      expect(tournament.start_countdown(120)).to be(true), "an earlier refusal doesn't get in the way"
    end

    it "stops with the tournament" do
      tournament.start_countdown(5)
      tournament.update!(status: :finished)

      expect(tournament).not_to be_countdown_running
      expect(tournament.start_countdown(5)).to be(false)
      expect(tournament.errors).to be_of_kind(:base, :countdown_finished)
    end

    it "can be cancelled" do
      tournament.start_countdown(5)
      tournament.cancel_countdown

      expect(tournament.reload.next_round_starts_at).to be_nil
      expect(tournament).not_to be_countdown_running
    end
  end
end

class Tournament < ApplicationRecord
  MAX_ROUNDS = 50
  COUNTDOWN_MINUTES = 1..120

  enum :pairing_system, { swiss: "swiss", round_robin: "round_robin" }, validate: true
  enum :status, { registration: "registration", in_progress: "in_progress", finished: "finished" }, default: :registration

  # Deleted in SQL (games cascade from rounds): members with games refuse to be destroyed one by one.
  has_many :participations, dependent: :delete_all
  has_many :players, through: :participations
  has_many :rounds, -> { order(:number) }, dependent: :delete_all, inverse_of: :tournament
  has_many :games, through: :rounds

  normalizes :name, :location, with: ->(value) { value.squish.presence }

  validates :name, presence: true, length: { maximum: 120 }
  validates :location, length: { maximum: 120 }
  # A round robin may leave it blank: one full cycle, decided when the tournament starts.
  validates :rounds_count, presence: true, if: -> { swiss? || !registration? }
  validates :rounds_count, numericality: { only_integer: true, in: 1..MAX_ROUNDS }, allow_nil: true
  validate :pairing_system_unchanged_after_start, :rounds_count_covers_fixed_rounds, on: :update

  after_update :replan_round_robin, if: -> { saved_change_to_rounds_count? && !saved_change_to_status? }

  broadcasts_refreshes

  scope :ordered, -> { in_order_of(:status, %w[ in_progress registration finished ]).order(starts_on: :desc, created_at: :desc) }

  def pairing_system_label
    self.class.human_enum_name(:pairing_system, pairing_system)
  end

  def status_label
    self.class.human_enum_name(:status, status)
  end

  # Swiss pairing-allocated byes score like a win; in a round robin the odd player just rests.
  def bye_points
    swiss? ? 1 : 0
  end

  def members_editable?
    !finished?
  end

  # Members still playing. Withdrawn ones keep their games and their place in the standings, but aren't paired again.
  def active_players
    players.merge(Participation.active)
  end

  # Swiss: the latest round. Round robin (paired up front): the first round still waiting for results.
  def current_round
    return rounds.last if swiss?

    rounds.where(id: games.pending.select(:round_id)).first || rounds.last
  end

  # Rounds that can't change anymore: every paired Swiss round; in a running round robin the rounds being played
  # or with results, since the later ones are only a plan.
  def fixed_rounds_count
    return rounds.size if swiss? || !in_progress?

    [ current_round&.number.to_i, games.where.not(result: %w[ pending bye ]).maximum("rounds.number").to_i ].max
  end

  def fixed_games
    games.where(rounds: { number: ..fixed_rounds_count })
  end

  # Whether a player joining now still gets to play.
  def rounds_ahead?
    rounds_count.to_i > fixed_rounds_count
  end

  def all_games_complete?
    !games.pending.exists?
  end

  def can_pair_next_round?
    swiss? && in_progress? && rounds.size < rounds_count && all_games_complete? && active_players.many?
  end

  def can_finish?
    in_progress? && rounds.any? && all_games_complete?
  end

  def can_reset?
    in_progress? && !games.where.not(result: %w[ pending bye ]).exists?
  end

  def start
    if !registration?
      errors.add(:base, :already_started)
    elsif participations.count < 2
      errors.add(:base, :not_enough_members)
    end
    return false if errors.any?

    transaction do
      if round_robin?
        update!(status: :in_progress, rounds_count: rounds_count || Pairing::RoundRobin.cycle_length(participations.count))
        Pairing::RoundRobin.new(self).call
      else
        in_progress!
        Pairing::NextRound.new(self).call
      end
    end
    true
  end

  def pair_next_round
    unless can_pair_next_round?
      errors.add(:base, :round_incomplete)
      return false
    end

    transaction { Pairing::NextRound.new(self).call }
    touch
    true
  end

  def finish
    unless can_finish?
      errors.add(:base, :results_missing)
      return false
    end

    finished!
  end

  # Throws away all pairings and goes back to registration. Allowed only before any game is played.
  def reset
    unless can_reset?
      errors.add(:base, :results_entered)
      return false
    end

    transaction do
      rounds.destroy_all
      # A round robin that was one full cycle stays "one full cycle", whatever the members are at the next start.
      one_cycle = round_robin? && rounds_count == Pairing::RoundRobin.cycle_length(participations.count)
      # With the rounds gone, members who withdrew have nothing left in the tournament.
      participations.withdrawn.delete_all
      update!(status: :registration, rounds_count: one_cycle ? nil : rounds_count)
    end
  end

  # Adds players at any stage before the finish. In a running round robin the rounds that haven't started yet are
  # paired again to include them; in a Swiss they simply join the next pairing.
  def enroll(new_players)
    transaction do
      new_players.each { |player| participations.create!(player:) }
      replan_round_robin
    end
  end

  # Removes a member who hasn't played yet, as if they never joined.
  def unenroll(participation)
    transaction do
      return false unless participation.destroy

      replan_round_robin
    end
    true
  end

  # A member leaving a running tournament keeps the games already played, so the standings and the opponents'
  # tie-breaks stay as they are, but nobody is paired against them again: a Swiss leaves them out of the next
  # pairing, a round robin pairs the rounds that haven't started again without them. A game of theirs still
  # waiting for a result is lost by forfeit; the arbiter can still change it.
  def withdraw(participation)
    unless in_progress? && !participation.withdrawn?
      errors.add(:base, :cannot_withdraw)
      return false
    end

    transaction do
      participation.update!(withdrawn_at: Time.current)
      # Re-pair before the forfeit: it may complete the round being played, and the next round would then be kept.
      replan_round_robin
      forfeit_pending_games(participation.player)
    end
    true
  end

  # Takes a withdrawn member back: they play from the next Swiss round, or in the round robin rounds that haven't
  # started. Games forfeited when they left keep their results.
  def reinstate(participation)
    unless in_progress? && participation.withdrawn?
      errors.add(:base, :cannot_reinstate)
      return false
    end

    transaction do
      participation.update!(withdrawn_at: nil)
      replan_round_robin
    end
    true
  end

  def remove_last_round
    round = current_round
    unless swiss? && in_progress? && round
      errors.add(:base, :cannot_delete_round)
      return false
    end

    transaction do
      round.destroy!
      rounds.reset
      rounds.empty? ? registration! : touch
    end
  end

  def standings
    Standings.new(self)
  end

  # The arbiter announces when the next round starts, and members see the time left on their phones.
  def start_countdown(minutes)
    minutes = Integer(minutes, exception: false)
    if finished?
      errors.add(:base, :countdown_finished)
      false
    elsif !minutes.in?(COUNTDOWN_MINUTES)
      errors.add(:base, :countdown_minutes, max: COUNTDOWN_MINUTES.max)
      false
    else
      update(next_round_starts_at: minutes.minutes.from_now)
    end
  end

  def cancel_countdown
    update(next_round_starts_at: nil)
  end

  def countdown_running?
    !finished? && next_round_starts_at.present? && next_round_starts_at.future?
  end

  private
    def replan_round_robin
      Pairing::RoundRobin.new(self).replan if round_robin? && in_progress?
    end

    def forfeit_pending_games(player)
      games.pending.merge(player.games).each do |game|
        game.update!(result: game.white_player_id == player.id ? :black_won : :white_won)
      end
    end

    def pairing_system_unchanged_after_start
      if pairing_system_changed? && !registration?
        errors.add(:pairing_system, :locked)
      end
    end

    def rounds_count_covers_fixed_rounds
      if rounds_count.present? && rounds_count < fixed_rounds_count
        errors.add(:rounds_count, :less_than_paired, count: fixed_rounds_count)
      end
    end
end

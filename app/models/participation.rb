class Participation < ApplicationRecord
  belongs_to :tournament, touch: true
  belongs_to :player

  # Signs the member in to this tournament on their phone; the arbiter shows it to them as a QR code.
  has_secure_token :access_token

  validates :player_id, uniqueness: { scope: :tournament_id }

  before_destroy :ensure_no_games_played, prepend: true

  scope :active, -> { where(withdrawn_at: nil) }
  scope :withdrawn, -> { where.not(withdrawn_at: nil) }

  def withdrawn?
    withdrawn_at.present?
  end

  # Games in rounds that are already fixed; planned round robin games are re-paired without the player.
  def games_played?
    tournament.fixed_games.merge(player.games).exists?
  end

  # The member's game in the round being played (a bye too), if they have one.
  def current_game
    tournament.current_round&.games&.merge(player.games)&.first
  end

  # Members enter the result of their own game in the round being played, once: a result already in is the
  # arbiter's to change.
  def can_report?(game)
    tournament.in_progress? && game.pending? && game == current_game
  end

  def report(game, result)
    return false unless result.in?(Game::RESULT_LABELS.keys) && can_report?(game)

    # The opponent may be entering it at the same moment: the first result in counts.
    game.with_lock { game.pending? && game.update(result:) }
  end

  private
    def ensure_no_games_played
      if games_played?
        errors.add(:base, :games_played, name: player.name)
        throw :abort
      end
    end
end

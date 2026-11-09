class Player < ApplicationRecord
  NICKNAME_FORMAT = /\A[\p{L}\p{N}_.\-]+\z/
  # Telegram's own rules for usernames. The username lets the arbiter reach the player, so only the arbiter's pages
  # show it: never members' phones or the hall screen.
  TELEGRAM_FORMAT = /\A[A-Za-z0-9_]{5,32}\z/
  TELEGRAM_LINK = %r{\A(?:https?://)?(?:www\.)?t(?:elegram)?\.me/}i

  has_many :participations, dependent: :destroy
  has_many :tournaments, through: :participations
  has_many :white_games, class_name: "Game", foreign_key: :white_player_id, inverse_of: :white_player
  has_many :black_games, class_name: "Game", foreign_key: :black_player_id, inverse_of: :black_player

  normalizes :name, :nickname, with: ->(value) { value.squish }
  # "@anna_k" and "https://t.me/anna_k" both come down to "anna_k"; a blank field to no username.
  normalizes :telegram, with: ->(value) { value.strip.sub(TELEGRAM_LINK, "").delete_prefix("@").presence }

  validates :name, presence: true, length: { maximum: 100 }
  validates :nickname, presence: true, length: { maximum: 30 }, uniqueness: { case_sensitive: false },
    format: { with: NICKNAME_FORMAT }
  validates :fide_rating, numericality: { only_integer: true, in: 1000..3000 }, allow_nil: true
  validates :telegram, format: { with: TELEGRAM_FORMAT }, allow_nil: true

  before_destroy :ensure_no_games_played, prepend: true

  scope :alphabetical, -> { order(:name, :nickname) }
  scope :by_rating, -> { order(arel_table[:fide_rating].desc.nulls_last, :name, :nickname) }
  scope :search, ->(query) {
    pattern = "%#{sanitize_sql_like(query.to_s.strip)}%"
    where("players.name ILIKE :pattern OR players.nickname ILIKE :pattern", pattern:)
  }

  def games
    Game.where(white_player: self).or(Game.where(black_player: self))
  end

  private
    def ensure_no_games_played
      if games.exists?
        errors.add(:base, :games_played, name:)
        throw :abort
      end
    end
end

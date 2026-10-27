class AddNextRoundStartsAtToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :next_round_starts_at, :datetime
  end
end

class AddTelegramToPlayers < ActiveRecord::Migration[8.1]
  def change
    add_column :players, :telegram, :string
  end
end

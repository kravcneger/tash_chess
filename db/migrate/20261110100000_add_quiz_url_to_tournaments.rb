class AddQuizUrlToTournaments < ActiveRecord::Migration[8.1]
  def change
    add_column :tournaments, :quiz_url, :string
  end
end

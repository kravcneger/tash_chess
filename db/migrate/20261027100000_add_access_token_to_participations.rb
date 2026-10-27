class AddAccessTokenToParticipations < ActiveRecord::Migration[8.1]
  # Members already in tournaments get their codes too.
  class Participation < ActiveRecord::Base
    has_secure_token :access_token
  end

  def up
    add_column :participations, :access_token, :string
    Participation.reset_column_information
    Participation.find_each(&:regenerate_access_token)

    change_column_null :participations, :access_token, false
    add_index :participations, :access_token, unique: true
  end

  def down
    remove_column :participations, :access_token
  end
end

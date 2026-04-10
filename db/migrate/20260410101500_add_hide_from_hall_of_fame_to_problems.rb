class AddHideFromHallOfFameToProblems < ActiveRecord::Migration[8.0]
  def change
    add_column :problems, :hide_from_hall_of_fame, :boolean, default: false, null: false
  end
end

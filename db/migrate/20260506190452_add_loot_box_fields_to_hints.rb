class AddLootBoxFieldsToHints < ActiveRecord::Migration[8.0]
  def change
    add_column :comments, :success_rate, :float, default: 100.0
  end
end

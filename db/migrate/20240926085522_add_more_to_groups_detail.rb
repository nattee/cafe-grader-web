class AddMoreToGroupsDetail < ActiveRecord::Migration[7.0]
  def change
    add_column :groups_users, :enabled, :bool, default: true
    add_column :groups_problems, :id, :primary_key
    add_column :groups_problems, :enabled, :bool, default: true
  end
end

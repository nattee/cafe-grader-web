class AddPointCostAndAllPointsToComments < ActiveRecord::Migration[8.0]
  def change
    add_column :comments, :point_cost, :float
    add_column :comments, :all_points, :boolean, default: false
  end
end

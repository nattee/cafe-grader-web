class AddPointsDeductedToCommentReveals < ActiveRecord::Migration[8.0]
  def change
    add_column :comment_reveals, :points_deducted, :float
  end
end

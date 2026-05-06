class AddIsSuccessToCommentReveals < ActiveRecord::Migration[8.0]
  def change
    add_column :comment_reveals, :is_success, :boolean, default: true
  end
end

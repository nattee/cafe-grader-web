class AddMaxSubmissionsToProblems < ActiveRecord::Migration[8.0]
  def change
    add_column :problems, :max_submissions, :integer
  end
end

class MoreNewEvaluation < ActiveRecord::Migration[7.0]
  def change
    add_column :evaluations, :result_text, :string
    add_column :evaluations, :isolate_message, :string
  end
end

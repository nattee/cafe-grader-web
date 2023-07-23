class AddMoreGraderProcess < ActiveRecord::Migration[7.0]
  def change
    create_table :host_problems do |t|
      t.references :host
      t.references :problem
      t.boolean :executable_ready
      t.integer :status, limit: 1, default: 0
      t.timestamps
    end

    add_column :grader_processes, :host_id, :integer
    add_column :grader_processes, :box_id, :integer
  end
end

class CreateScores < ActiveRecord::Migration[8.0]
  def change
    create_table :score_submissions do |t|
      t.references :dataset, null: false
      t.references :submission, null: false
      t.decimal :points, precision: 8, scale: 4
      t.integer :status, limit: 1, default: 0, null: false

      t.timestamps
    end

    create_table :score_users do |t|
      t.references :dataset, null: false
      t.references :user, null: false
      t.decimal :points, precision: 8, scale: 4
      t.integer :status, limit: 1, default: 0, null: false

      t.timestamps
    end
  end
end

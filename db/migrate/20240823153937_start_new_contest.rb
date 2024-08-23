class StartNewContest < ActiveRecord::Migration[7.0]
  def change
    drop_table :contests_users
    drop_table :contests_problems

    create_table :contests_problems, id: false, primary: [:contest_id, :problem_id],
      options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci" do |t|
        t.belongs_to :contest
        t.belongs_to :problem
        t.integer :numbering
    end

    create_table :contests_users, id: false, primary: [:contest_id, :user_id],
      options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci" do |t|
        t.belongs_to :contest
        t.belongs_to :user
        t.decimal :current_score
        t.datetime :last_heartbeat
        t.integer :start_offset_second, default: 0
        t.integer :extra_time_second, default: 0
        t.string :remark
    end
  end
end

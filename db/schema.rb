# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180612102327) do

  create_table "announcements", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string   "author"
    t.text     "body",         limit: 65535
    t.boolean  "published"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "frontpage",                  default: false
    t.boolean  "contest_only",               default: false
    t.string   "title"
    t.string   "notes"
  end

  create_table "contests", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string   "title"
    t.boolean  "enabled"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "name"
  end

  create_table "contests_problems", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer "contest_id"
    t.integer "problem_id"
  end

  create_table "contests_users", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer "contest_id"
    t.integer "user_id"
  end

  create_table "countries", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "descriptions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.text     "body",       limit: 65535
    t.boolean  "markdowned"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "grader_configurations", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string   "key"
    t.string   "value_type"
    t.string   "value"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "description", limit: 65535
  end

  create_table "grader_processes", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string   "host"
    t.integer  "pid"
    t.string   "mode"
    t.boolean  "active"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "task_id"
    t.string   "task_type"
    t.boolean  "terminated"
    t.index ["host", "pid"], name: "index_grader_processes_on_host_and_pid", using: :btree
  end

  create_table "groups", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string "name"
    t.string "description"
  end

  create_table "groups_problems", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer "problem_id", null: false
    t.integer "group_id",   null: false
    t.index ["group_id", "problem_id"], name: "index_groups_problems_on_group_id_and_problem_id", using: :btree
  end

  create_table "groups_users", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer "group_id", null: false
    t.integer "user_id",  null: false
    t.index ["user_id", "group_id"], name: "index_groups_users_on_user_id_and_group_id", using: :btree
  end

  create_table "heart_beats", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "user_id"
    t.string   "ip_address"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "status"
    t.index ["updated_at"], name: "index_heart_beats_on_updated_at", using: :btree
  end

  create_table "languages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string "name",        limit: 10
    t.string "pretty_name"
    t.string "ext",         limit: 10
    t.string "common_ext"
  end

  create_table "logins", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "user_id"
    t.string   "ip_address"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "messages", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "sender_id"
    t.integer  "receiver_id"
    t.integer  "replying_message_id"
    t.text     "body",                limit: 65535
    t.boolean  "replied"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "problems", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string  "name",                 limit: 30
    t.string  "full_name"
    t.integer "full_score"
    t.date    "date_added"
    t.boolean "available"
    t.string  "url"
    t.integer "description_id"
    t.boolean "test_allowed"
    t.boolean "output_only"
    t.string  "description_filename"
    t.boolean "view_testcase"
  end

  create_table "problems_tags", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer "problem_id"
    t.integer "tag_id"
    t.index ["problem_id", "tag_id"], name: "index_problems_tags_on_problem_id_and_tag_id", unique: true, using: :btree
    t.index ["problem_id"], name: "index_problems_tags_on_problem_id", using: :btree
    t.index ["tag_id"], name: "index_problems_tags_on_tag_id", using: :btree
  end

  create_table "rights", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string "name"
    t.string "controller"
    t.string "action"
  end

  create_table "rights_roles", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer "right_id"
    t.integer "role_id"
    t.index ["role_id"], name: "index_rights_roles_on_role_id", using: :btree
  end

  create_table "roles", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string "name"
  end

  create_table "roles_users", id: false, force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer "role_id"
    t.integer "user_id"
    t.index ["user_id"], name: "index_roles_users_on_user_id", using: :btree
  end

  create_table "sessions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string   "session_id"
    t.text     "data",       limit: 65535
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_sessions_on_session_id", using: :btree
    t.index ["updated_at"], name: "index_sessions_on_updated_at", using: :btree
  end

  create_table "sites", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string   "name"
    t.boolean  "started"
    t.datetime "start_time"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "country_id"
    t.string   "password"
  end

  create_table "submission_view_logs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "user_id"
    t.integer  "submission_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "submissions", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "user_id"
    t.integer  "problem_id"
    t.integer  "language_id"
    t.text     "source",                limit: 16777215
    t.binary   "binary",                limit: 65535
    t.datetime "submitted_at"
    t.datetime "compiled_at"
    t.text     "compiler_message",      limit: 65535
    t.datetime "graded_at"
    t.integer  "points"
    t.text     "grader_comment",        limit: 65535
    t.integer  "number"
    t.string   "source_filename"
    t.float    "max_runtime",           limit: 24
    t.integer  "peak_memory"
    t.integer  "effective_code_length"
    t.string   "ip_address"
    t.index ["user_id", "problem_id", "number"], name: "index_submissions_on_user_id_and_problem_id_and_number", unique: true, using: :btree
    t.index ["user_id", "problem_id"], name: "index_submissions_on_user_id_and_problem_id", using: :btree
  end

  create_table "tags", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string   "name",                      null: false
    t.text     "description", limit: 65535
    t.boolean  "public"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  create_table "tasks", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "submission_id"
    t.datetime "created_at"
    t.integer  "status"
    t.datetime "updated_at"
    t.index ["submission_id"], name: "index_tasks_on_submission_id", using: :btree
  end

  create_table "test_pairs", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "problem_id"
    t.text     "input",      limit: 16777215
    t.text     "solution",   limit: 16777215
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "test_requests", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "user_id"
    t.integer  "problem_id"
    t.integer  "submission_id"
    t.string   "input_file_name"
    t.string   "output_file_name"
    t.string   "running_stat"
    t.integer  "status"
    t.datetime "updated_at"
    t.datetime "submitted_at"
    t.datetime "compiled_at"
    t.text     "compiler_message", limit: 65535
    t.datetime "graded_at"
    t.string   "grader_comment"
    t.datetime "created_at"
    t.float    "running_time",     limit: 24
    t.string   "exit_status"
    t.integer  "memory_usage"
    t.index ["user_id", "problem_id"], name: "index_test_requests_on_user_id_and_problem_id", using: :btree
  end

  create_table "testcases", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "problem_id"
    t.integer  "num"
    t.integer  "group"
    t.integer  "score"
    t.text     "input",      limit: 4294967295
    t.text     "sol",        limit: 4294967295
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["problem_id"], name: "index_testcases_on_problem_id", using: :btree
  end

  create_table "user_contest_stats", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.integer  "user_id"
    t.datetime "started_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "forced_logout"
  end

  create_table "users", force: :cascade, options: "ENGINE=InnoDB DEFAULT CHARSET=latin1" do |t|
    t.string   "login",           limit: 50
    t.string   "full_name"
    t.string   "hashed_password"
    t.string   "salt",            limit: 5
    t.string   "alias"
    t.string   "email"
    t.integer  "site_id"
    t.integer  "country_id"
    t.boolean  "activated",                  default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "section"
    t.boolean  "enabled",                    default: true
    t.string   "remark"
    t.string   "last_ip"
    t.index ["login"], name: "index_users_on_login", unique: true, using: :btree
  end

  add_foreign_key "problems_tags", "problems"
  add_foreign_key "problems_tags", "tags"
end

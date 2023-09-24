Rails.application.routes.draw do
  resources :tags
  get "sources/direct_edit"

  root :to => 'main#login'

  #logins
  match 'login/login',  to: 'login#login', via: [:get,:post]

  resources :contests
  resources :sites
  resources :test

  resources :messages do
    member do
      get 'hide'
      post 'reply'
    end
    collection do
      get 'console'
      get 'list_all'
    end
  end

  resources :announcements do
    member do
      get 'toggle','toggle_front'
    end
  end

  resources :problems do
    member do
      get 'toggle'
      get 'toggle_test'
      get 'toggle_view_testcase'
      get 'stat'
      get 'get_statement(/:filename)', as: 'get_statement', action: 'get_statement'
      post 'add_dataset'
      post 'import_testcases'
    end
    collection do
      get 'turn_all_off'
      get 'turn_all_on'
      get 'import'
      get 'manage'
      get 'quick_create'
      post 'do_manage'
      post 'do_import'
    end
  end

  resources :datasets, only: [:update, :destroy] do
    member do
      post 'manager/delete/:mg_id', action: 'manager_delete', as: 'manager_delete'
      post 'manager/view/:mg_id', action: 'manager_view', as: 'manager_view'
      post 'testcase/input/:tc_id', action: 'testcase_input', as: 'testcase_input'
      post 'testcase/sol/:tc_id', action: 'testcase_sol', as: 'testcase_sol'
      post 'testcase/delete/:tc_id', action: 'testcase_delete', as: 'testcase_delete'
      post 'set_as_live'
      post 'view'
      post 'rejudge'
    end
  end

  resources :groups do
    member do
      post 'add_user', to: 'groups#add_user', as: 'add_user'
      delete 'remove_user/:user_id', to: 'groups#remove_user', as: 'remove_user'
      delete 'remove_all_user', to: 'groups#remove_all_user', as: 'remove_all_user'
      post 'add_problem', to: 'groups#add_problem', as: 'add_problem'
      delete 'remove_problem/:problem_id', to: 'groups#remove_problem', as: 'remove_problem'
      delete 'remove_all_problem', to: 'groups#remove_all_problem', as: 'remove_all_problem'
      get 'toggle'
    end
    collection do

    end
  end

  resources :testcases, only: [] do
    member do
      get 'download_input'
      get 'download_sol'
    end
    collection do
      get 'show_problem/:problem_id(/:test_num)' => 'testcases#show_problem', as: 'show_problem'
      get 'download_manager/:problem_id/:mg_id', as: 'download_manager', action: 'download_manager'
    end
  end

  resources :grader_configuration, controller: 'configurations' do
    collection do
      get 'set_exam_right(/:value)', action: 'set_exam_right', as: 'set_exam_right'
    end
    member do
      patch 'toggle'
    end
  end

  #for each user editing their own
  resources :users, only: [:new] do
    member do
      get 'toggle_activate', 'toggle_enable'
      get 'stat'
    end
    collection do
      get 'profile'
      post 'chg_passwd'
      post 'chg_default_language'
      patch 'update_self'
    end
  end

  resources :submissions do
    member do
      get 'download'
      post 'compiler_msg'
      get 'rejudge'
      get 'set_tag'
    end
    collection do
      get 'prob/:problem_id', to: 'submissions#index', as: 'problem'
      get 'direct_edit_problem/:problem_id(/:user_id)', to: 'submissions#direct_edit_problem', as: 'direct_edit_problem'
      get 'get_latest_submission_status/:uid/:pid', to: 'submissions#get_latest_submission_status', as: 'get_latest_submission_status'
    end
  end


  #user admin
  resources :user_admin  do
    collection do
      match 'bulk_manage', via: [:get, :post]
      get 'bulk_mail'
      get 'import'
      get 'new_list'
      get 'admin'
      get 'active'
      get 'mass_mailing'
      match 'modify_role', via: [:get, :post]
      match 'create_from_list', via: [:get, :post]
      match 'random_all_passwords', via: [:get, :post]
    end
    member do
      get 'clear_last_ip'
    end
  end

  resources :contest_management, only: [:index] do
    collection do
      get 'user_stat'
      get 'clear_stat'
      get 'clear_all_stat'
      get 'change_contest_mode'
    end
  end

  #get 'user_admin', to: 'user_admin#index'
  #get 'user_admin/bulk_manage', to: 'user_admin#bulk_manage', as: 'bulk_manage_user_admin'
  #post 'user_admin', to: 'user_admin#create'
  #delete 'user_admin/:id', to: 'user_admin#destroy', as: 'user_admin_destroy'

  #singular resource
  #---- BEWARE ---- singular resource maps to plural controller by default, we can override by provide controller name directly
  #report
  resource :report, only: [], controller: 'report' do
    get 'login'
    get 'multiple_login'
    get 'problem_hof(/:id)', action: 'problem_hof', as: 'problem_hof'
    get 'max_score'
    post 'show_max_score'
    get 'stuck'
    get 'cheat_report'
    post 'cheat_report'
    get 'cheat_scrutinize'
    post 'cheat_scrutinize'
    get 'submission'
    post 'submission_query'
    get 'login_stat'
    post 'login_stat'
    get 'login'
    post 'login_summary_query'
    post 'login_detail_query'
  end
  #get 'report/current_score', to: 'report#current_score', as: 'report_current_score'
  #get 'report/problem_hof(/:id)', to: 'report#problem_hof', as: 'report_problem_hof'
  #get "report/login"
  #get 'report/max_score', to: 'report#max_score', as: 'report_max_score'
  #post 'report/show_max_score', to: 'report#show_max_score', as: 'report_show_max_score'

  resource :main, only: [], controller: 'main' do
    get 'login'
    get 'logout'
    get 'list'
    get 'submission(/:id)', action: 'submission', as: 'main_submission'
    get 'announcements'
    get 'help'
    post 'submit'
  end
  #main
  #get "main/list"
  #get 'main/submission(/:id)', to: 'main#submission', as: 'main_submission'
  #post 'main/submit', to: 'main#submit'
  #get 'main/announcements', to: 'main#announcements'

  namespace :worker do
    post 'compiled_submission/:id', action: :compiled_submission, as: :compiled_submission
    get 'get_compiled_submission/:sub_id/:attach_id', action: :get_compiled_submission, as: :get_compiled_submission
    get 'get_manager/:ds_id/:manager_id', action: :get_manager, as: :get_manager
  end

  get 'heartbeat/:id/edit' => 'heartbeat#edit'

  #grader
  #get 'graders/list', to: 'graders#list', as: 'grader_list'
  namespace :graders do
    get 'task/:id/:type', action: 'task', as: 'task'
    get 'view/:id/:type', action: 'view', as: 'view'
    #get 'clear/:id', action: 'clear', as: 'clear'
    #get 'start_grading'
    #get 'start_exam'
    #get 'clear_all'
    #get 'stop_all'

    #get 'stop'
    #get 'clear_terminated'
    get 'list'
    post 'set_enabled/:id/:enabled', as: :set_enabled, action: :set_enabled
  end


  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id))(.:format)', via:  [:get, :post]
end

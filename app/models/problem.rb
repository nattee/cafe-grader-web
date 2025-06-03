class Problem < ApplicationRecord

  #how the submission should be compiled
  enum compilation_type:  {self_contained: 0,
                           with_managers: 1}
  enum task_type: { batch: 0 }
  #belongs_to :description

  has_and_belongs_to_many :contests, :uniq => true

  #has_and_belongs_to_many :groups
  has_many :groups_problems, class_name: 'GroupProblem', dependent: :destroy
  has_many :groups, :through => :groups_problems

  has_many :problems_tags, class_name: 'ProblemTag', dependent: :destroy
  has_many :tags, through: :problems_tags

  has_many :test_pairs, :dependent => :delete_all

  #testcase is all the testcases
  has_many :testcases, :dependent => :destroy

  has_many :submissions, :dependent => :destroy

  has_many :datasets, :dependent => :destroy
  belongs_to :live_dataset, class_name: 'Dataset'

  validates_presence_of :name
  #validates_format_of :name, :with => /\A\w+\z/
  validates_presence_of :full_name

  scope :available, -> { where(available: true) }

  # return problems that is enabled and is in an enabled group that has the given user
  # this does not check whether the user is enabled
  #
  # It always considers groups, regardless of the group mode configuration
  # When group mode is false, use Problem.available_problems instead
  scope :group_submittable_by_user, ->(user_id) {
    joins(groups_problems: {group: :groups_users})
      .where(available: true)                   #available problems only
      .where('groups.enabled': true)            #groups is enabled
      .where('groups_users.user_id': user_id)   #user is in the group
      .where('groups_users.enabled': true)      #user in the group is enabled
      .where('groups_problems.enabled': true)   #problem is enabled
      .distinct(:id)                            #get distinct
  }

  # Similar to group_submittable_by_user, but does not required GroupProblem.enabled to be enabled
  scope :group_reportable_by_user, ->(user_id) {
    group_actionable_by_user(user_id,['editor','reporter'])
  }

  # Similar to group_submittable_by_user, but does not required GroupProblem.enabled to be enabled
  scope :group_editable_by_user, ->(user_id) {
    group_actionable_by_user(user_id,['editor'])
  }

  scope :group_actionable_by_user, ->(user_id,roles = ['editor']) { 
    joins(groups_problems: {group: :groups_users})
      .where(available: true)                   #available problems only
      .where('groups.enabled': true)            #groups is enabled
      .where('groups_users.user_id': user_id)   #user is in the group
      .where('groups_users.role': roles)        #filter for user with roles
      .distinct(:id)                            #get distinct
  }

  scope :contests_problems_for_user, ->(user_id) {
    now = Time.zone.now
    joins(contests_problems: {contest: :contests_users})
      .where(available: true)                   #available problems only
      .where('contests.enabled': true)          #contests is enabled
      .where('contests_users.user_id': user_id) #user is in the contest
      .where('contests_users.enabled': true)    #user in the contest is enabled
      .where('contests_problems.enabled': true) #problem is enabled
      .where('ADDTIME(contests.start,contests_users.start_offset_second) <= ?',now)
      .where('ADDTIME(contests.stop,contests_users.extra_time_second) >= ?',now)
      .distinct(:problem_id)                    #get distinct
  }

  scope :default_order, -> { order(date_added: :desc).order(:name)  }

  DEFAULT_TIME_LIMIT = 1
  DEFAULT_MEMORY_LIMIT = 32

  # attachment here are the public one,
  # if the user has the right to submit, the user can see the attachments (and statement)
  has_one_attached :statement
  has_one_attached :attachment  #this is public files seen by contestant

  def set_default_value

  end

  def public_tags
    tags.where(public: true)
  end


  def can_view_testcase
    return GraderConfiguration.show_testcase && self.view_testcase
  end

  def get_jschart_history
    start = 4.month.ago.beginning_of_day
    start_date = start.to_date
    count = Submission.where(problem: self).where('submitted_at >= ?', start).group('DATE(submitted_at)').count
    i = 0
    label = []
    value = []
    while (start_date + i < Time.zone.now.to_date)
      if (start_date+i).day == 1
        #label << (start_date+i).strftime("%d %b %Y")
        #label << (start_date+i).strftime("%d")
      else
        #label << ' '
        #label << (start_date+i).strftime("%d")
      end
      label << (start_date+i).strftime("%d-%b")
      value << (count[start_date+i] || 0)
      i+=1
    end
    return {labels: label,datasets: [label:'sub',data: value, backgroundColor: 'rgba(54, 162, 235, 0.2)', borderColor: 'rgb(75, 192, 192)']}
  end

  def get_next_dataset_name(base = 'Dataset')
    num = 1
    name = base + " #{num}"
    while datasets.where(name: name).count > 0
      num += 1
      name = base + " #{num}"
    end
    return name
  end


  def self.create_from_import_form_params(params, old_problem=nil)
    org_problem = old_problem || Problem.new
    import_params, problem = Problem.extract_params_and_check(params,
                                                              org_problem)
    if !problem.errors.empty?
      return problem, 'Error importing'
    end

    problem.date_added = Time.new
    problem.test_allowed = true
    problem.output_only = false
    problem.available = false

    if not problem.save
      return problem, 'Error importing'
    end

    import_to_db = params.has_key? :import_to_db

    importer = TestdataImporter.new(problem)

    if not importer.import_from_file(import_params[:file],
                                     import_params[:time_limit],
                                     import_params[:memory_limit],
                                     import_params[:checker_name],
                                     import_to_db)
      problem.errors.add(:base,'Import error.')
    end

    return problem, importer.log_msg
  end

  def self.download_file_basedir
    return "#{Rails.root}/data/tasks"
  end

  def get_submission_stat
    result = Hash.new
    #total number of submission
    result[:total_sub] = Submission.where(problem_id: self.id).count
    result[:attempted_user] = Submission.where(problem_id: self.id).group(:user_id)
    result[:pass] = Submission.where(problem_id: self.id).where("points >= ?",100).count
    return result
  end

  def long_name
    "[#{name}] #{full_name}"
  end

  # ids_string is something like ['1','3','7']
  # which correspond to the submitted value from  select2 multiple selection
  def set_permitted_lang_from_ids_string(ids_string)
    lang_names = ids_string.reject(&:empty?).map { |x| Language.find(x.to_i).name }.join(' ')
    self.permitted_lang = lang_names
  end

  # return ids array of permitted lang
  # if permitted_lang is blank, show nil 
  def get_permitted_lang_as_ids(when_blank: Language.ids)
    return when_blank if self.permitted_lang.blank?
    return Language.where(name: self.permitted_lang.split(' ').uniq).ids
  end

  #this function return a content generated for "all_tests.cfg"
  #  from the legacy code (Aj. Pong's) 
  #  This is definitely not complete but it works in general cases
  def build_legacy_config_file
    default = {
      time_limit: 1.0,
      mem_limit: 512,
      score: 10
    }

    result = ["problem do"]
    result << "  num_tests #{testcases.count}"
    result << "  full_score #{testcases.count}"
    result << "  time_limit_each #{default[:time_limit]}"
    result << "  mem_limit_each #{default[:mem_limit]}"
    result << "  score_each #{default[:score]}"
    result << ""

    testcases.order(:num).each do |tc|
      result << "  run #{tc.num} do"
      result << "    tests #{tc.num}"
      result << "    scores #{tc.score}"
      result << "  end"
      result << ""
    end

    result << "end\n"
    return result.join "\n"
  end


  #TODO: change to language specific
  def exec_filename(language)
    case language.name
    when 'cpp'
      'a.out'
    when 'python'
      'cafe_code.py'
    when 'java','digital'
      #for java, the compilation create a shell script that runs the file
      'run.sh'
    else
      'submission'
    end
  end

  # export  the problem into the default dump dir
  def export
    pe = ProblemExporter.new
    pe.export_problem_to_dir(self, zip: true)
  end

end

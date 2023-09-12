class Problem < ApplicationRecord

  #how the submission should be compiled
  enum compilation_type:  {self_contained: 0,
                           with_managers: 1}
  enum task_type: { batch: 0}
  #belongs_to :description

  has_and_belongs_to_many :contests, :uniq => true

  #has_and_belongs_to_many :groups
  has_many :groups_problems, class_name: 'GroupProblem'
  has_many :groups, :through => :groups_problems

  has_many :problems_tags, class_name: 'ProblemTag'
  has_many :tags, through: :problems_tags

  has_many :test_pairs, :dependent => :delete_all

  #testcase is all the testcases
  has_many :testcases, :dependent => :destroy

  has_many :submissions

  has_many :datasets
  belongs_to :live_dataset, class_name: 'Dataset'

  validates_presence_of :name
  validates_format_of :name, :with => /\A\w+\z/
  validates_presence_of :full_name

  scope :available, -> { where(available: true) }

  DEFAULT_TIME_LIMIT = 1
  DEFAULT_MEMORY_LIMIT = 32

  # attachment here are the public one,
  # if the user has the right to submit, the user can see the attachments (and statement)
  has_one_attached :statement
  has_many_attached :attachments  #this is public files seen by contestant

  def set_default_value

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

  def self.available_problems
    available.order(date_added: :desc).order(:name)
    #Problem.available.all(:order => "date_added DESC, name ASC")
  end

  def self.create_from_import_form_params(params, old_problem=nil)
    org_problem = old_problem || Problem.new
    import_params, problem = Problem.extract_params_and_check(params,
                                                              org_problem)

    if !problem.errors.empty?
      return problem, 'Error importing'
    end

    problem.full_score = 100
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
    result[:pass] = Submission.where(problem_id: self.id).where("points >= ?",self.full_score).count
    return result
  end

  def long_name
    "[#{name}] #{full_name}"
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
      'code.pyc'
    when 'java','digital'
      #for java, the compilation create a shell script that runs the file
      'run.sh'
    else
      'submission'
    end
  end

  protected

  def self.migrate_pdf_to_activestorage
    Problem.where.not(description_filename: nil).each do |p|
      file = Rails.root.join('data','tasks',p.id.to_s,p.description_filename)
      if file.exist?
        p.statement.attach(io: File.open(file), filename: p.description_filename)
        puts "Add #{file} to #{p.name}"
      end
    end
  end

  # check the old /judge/ev folder for test_cases/all_tests.cfg
  # change the live dataset of the problem of that ev folder
  # with the memory limit and time limit
  #
  # Additionally, see if this one has grouped subtask
  # if so, change the scoring of the live-dataset of to :GroupMin
  def self.migrate_subtask
    dir = Rails.root.join '../judge/ev/*'
    Dir[dir].each do |ev_dir|
      pn = Pathname.new ev_dir
      p = Problem.where(name: pn.basename.to_s).first
      next unless p

      #now p is the problem with the same name as the ev sub-dir

      r = parse_all_test_cfg(pn + 'test_cases/all_tests.cfg',p)
      p.live_dataset.update(memory_limit: r[:mem_limit], time_limit: r[:time_limit])
      if (r[:group])
        p.live_dataset.st_group_min!

        #show debug info
        puts "Found problem #{p.name} (#{p.id}) with grouped testcase"
      end
    end
  end

  public
  def read_managers_from_ev(ev_dir)
    pi = ProblemImporter.new
    pi.import_dataset_from_dir(ev_dir,self.name, full_name: self.full_name, dataset: self.live_dataset, do_testcase: false, do_statement: false)
  end

  protected

  def self.migrate_manager_from_ev
    dir = Rails.root.join '../judge/ev/*'
    Dir[dir].each do |ev_dir|
      pn = Pathname.new ev_dir
      p = Problem.where(name: pn.basename.to_s).first
      next unless p

      #now p is the problem with the same name as the ev sub-dir
      pi = ProblemImporter.new
      pi.import_dataset_from_dir(ev_dir,p.name,full_name: p.full_name, dataset: p.live_dataset, do_testcase: false, do_statement: false)
    end
  end

  def self.parse_all_test_cfg(filename,problem)
    on_run = false
    run = nil
    tests = nil
    scores = nil
    result = {}
    File.foreach(filename).each do |line|
      #time limit
      md = /time_limit_each\s+(\d+\.?\d*)/.match line
      result[:time_limit] = md[1].to_f if md

      # mem limit
      md = /mem_limit_each\s+(\d+\.?\d*)/.match line
      result[:mem_limit] = md[1].to_f if md

      # score_each
      md = /score_each\s+(\d+\.?\d*)/.match line
      result[:score_each] = md[1].to_f if md

      #run detect
      md = /run\s+(\d+)\s+do/.match line
      if (md && !on_run)
        run = md[1].to_i
        on_run = true
        tests = nil
        scores = nil
      end

      #test on run
      md = /tests\s+([\d,\s]*)/.match line
      if (md && on_run)
        tests = md[1].split(',').map { |x| x.to_i}
      end

      #score on run
      md = /scores\s+([\d,\s]*)/.match line
      if (md && on_run)
        scores = md[1].split(',').map { |x| x.to_i}
      end

      md = /end/.match line
      if (md && on_run)
        result[:group] = true if tests && tests.count > 1
        on_run = false
        result[run] = {tests: tests,scores: scores, errors: []}
        result[run][:errors] << "no test" unless tests
        result[run][:errors] << "no scores" unless scores
        tests.each do |num|
          problem.live_dataset.testcases.where(num: num).update(group: run,weight: scores[0], group_name: run)
        end
      end
    end
    return result
  end

end

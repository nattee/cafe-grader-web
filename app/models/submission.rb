class Submission < ApplicationRecord

  enum tag: {default: 0, model: 1}, _prefix: true
  enum status: {submitted: 0, evaluating: 1, done: 2, compilation_error: 3, compilation_success: 4, grader_error: 5}


  belongs_to :language
  belongs_to :problem
  belongs_to :user

  has_many :evaluations, :dependent => :destroy

  before_validation :assign_language
  before_save :assign_latest_number_if_new_recond

  validates_presence_of :source
  validates_length_of :source, :maximum => 1_000_000, :allow_blank => true, :message => 'code too long, the limit is 1,000,000 bytes'
  validates_length_of :source, :minimum => 1, :allow_blank => true, :message => 'too short'
  validate :must_have_valid_problem
  validate :must_specify_language

  has_one :task

  has_many_attached :compiled_files

  def add_judge_job(dataset = problem.live_dataset,priority = 0)
    evaluations.delete_all
    self.update(status: 'submitted', points: nil, grader_comment: nil,graded_at: nil)
    Job.add_grade_submission_job(self,dataset,priority)
  end


  def set_grading_complete(point,grading_text,max_time,max_mem)
    update(points: point, status: :done, graded_at: Time.zone.now, grader_comment: grading_text, max_runtime: max_time, peak_memory: max_mem)
  end

  def set_grading_error(error_text)
    update(points: 0, status: :grader_error, graded_at: Time.zone.now, grader_comment: error_text)
  end


  def self.find_last_by_user_and_problem(user_id, problem_id)
    where("user_id = ? AND problem_id = ?",user_id,problem_id).last
  end

  def self.find_all_last_by_problem(problem_id)
    # need to put in SQL command, maybe there's a better way
    Submission.includes(:user).find_by_sql("SELECT * FROM submissions " +
      "WHERE id = " +
        "(SELECT MAX(id) FROM submissions AS subs " +
      "WHERE subs.user_id = submissions.user_id AND " +
        "problem_id = " + problem_id.to_s + " " +
      "GROUP BY user_id) " +
      "ORDER BY user_id")
  end

  def self.find_in_range_by_user_and_problem(user_id, problem_id,since_id,until_id)
    records = Submission.where(problem_id: problem_id,user_id: user_id)
    records = records.where('id >= ?',since_id) if since_id and since_id > 0
    records = records.where('id <= ?',until_id) if until_id and until_id > 0
    records.all
  end

  def self.find_last_for_all_available_problems(user_id)
    submissions = Array.new
    problems = Problem.available
    problems.each do |problem|
      sub = Submission.find_last_by_user_and_problem(user_id, problem.id)
      submissions << sub if sub!=nil
    end
    submissions
  end

  def self.find_by_user_problem_number(user_id, problem_id, number)
    where("user_id = ? AND problem_id = ? AND number = ?",user_id,problem_id,number).first
  end

  def self.find_all_by_user_problem(user_id, problem_id)
    where("user_id = ? AND problem_id = ?",user_id,problem_id)
  end

  def download_filename
    if self.problem.output_only
      return self.source_filename
    else
      timestamp = self.submitted_at.localtime.strftime("%H%M%S")
      return "#{self.problem.name}-#{timestamp}.#{self.language.ext}"
    end
  end

  protected

  def self.find_option_in_source(option, source)
    if source==nil
      return nil
    end
    i = 0
    source.each_line do |s|
      if s =~ option
        words = s.split
        return words[1]
      end
      i = i + 1
      if i==10
        return nil
      end
    end
    return nil
  end

  def self.find_language_in_source(source, source_filename="")
    langopt = find_option_in_source(/^LANG:/,source)
    if langopt
      return (Language.find_by_name(langopt) ||
              Language.find_by_pretty_name(langopt))
    else
      if source_filename
        return Language.find_by_extension(source_filename.split('.').last)
      else
        return nil
      end
    end
  end

  def self.find_problem_in_source(source, source_filename="")
    prob_opt = find_option_in_source(/^TASK:/,source)
    if problem = Problem.find_by_name(prob_opt)
      return problem
    else
      if source_filename
        return Problem.find_by_name(source_filename.split('.').first)
      else
        return nil
      end
    end
  end


  def assign_language
    if self.language == nil
      # detect from filename
      self.language = Submission.find_language_in_source(self.source,
                                                         self.source_filename)

    end

    # if problem permit only one language, we always use that one
    # even when the problem already have one
    permitted_lang_ids = self.problem.get_permitted_lang_as_ids
    if permitted_lang_ids.count == 1
      self.language_id = permitted_lang_ids[0]
    end
  end

  # validation codes
  def must_specify_language
    return if self.source==nil

    # for output_only tasks
    return if self.problem!=nil and self.problem.output_only

    if self.language == nil
      errors.add(:source,:invalid,message: "Cannot detect language. Did you submit a correct source file?")
    end
  end

  def must_have_valid_problem
    return if self.source==nil
    if self.problem==nil
      errors.add(:problem,:blank,'aaa')
    else
      #admin always have right
      return if self.user.admin?

      #check if user has the right to submit the problem
      errors[:base] << "Authorization error: you have no right to submit to this problem" if (!self.user.available_problems.include?(self.problem)) and (self.new_record?)
    end
  end

  # callbacks
  def assign_latest_number_if_new_recond
    return if !self.new_record?
    latest = Submission.find_last_by_user_and_problem(self.user_id, self.problem_id)
    self.number = (latest==nil) ? 1 : latest.number + 1;
  end

  public

end

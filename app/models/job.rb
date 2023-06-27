class Job < ApplicationRecord
  enum status: {wait: 0, process: 1, success: 2, error: 3}
  enum job_type: {preprocess: 0, compile: 1, evaluate: 2, score: 3}

  scope :oldest_waiting, -> {where(status: :wait)}
  scope :finished, -> {where(status: [:done,:error])}

  belongs_to :grader_process

  def report(status,result)
    update(status: status,result: result)
  end

  def self.add_compiling_job(submission,parent_job_id = nil)
    Job.create(parent_job_id: parent_job_id, job_type: :compile, arg: submission.id )
  end

  def self.add_evaluation_jobs(submission,parent_job_id = nil)
    submission.data_set.testcases.each do |testcase|
      Job.create(parent_job_id: parent_job_id,
                 job_type: :evaluate,
                 arg: submission.id,
                 param: {testcase: testcases.id}.to_json )
    end
  end

  def self.add_scoring_job(submission,parent_job_id = nil)
    Job.create(parent_job_id: parent_job_id, job_type: :score, arg: submission.id )
  end

  # fetch jobs from the queue, only for given job_types, if given
  def self.take_oldest_waiting_job(grader_process,job_types = [])
    job = nil
    Job.transaction do
      # pick non-locked oldest_waiting
      # https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-reads.html#innodb-locking-reads-nowait-skip-locked
      jobs = Job.lock("FOR UPDATE SKIP LOCKED").oldest_waiting
      jobs = jobs.where(job_type: job_types) if job_types.count > 0
      job = jobs.first

      if job
        job.update(status: :process,grader_process: grader_process)
      end
    end
    return job
  end

  def self.all_evaluate_job_complete(job)
    Job.where(parent_job: job.parent_job,job_type: :evaluate).where.not(status: :success).count == 0
  end


end

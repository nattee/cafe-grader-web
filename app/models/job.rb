class Job < ApplicationRecord
  enum status: {wait: 0, process: 1, success: 2, error: 3}
  enum job_type: {preprocess: 0, compile: 1, evaluate: 2, score: 3}

  scope :oldest_waiting, -> {where(status: :wait)}
  scope :finished, -> {where(status: [:done,:error])}

  belongs_to :grader_process


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

  def report(status,result)
    update(status: status,result: result)
  end

end

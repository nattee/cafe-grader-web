class Job < ApplicationRecord
  enum :status, {wait: 0, process: 1, success: 2, error: 3}
  enum :job_type, {preprocess: 0, compile: 1, evaluate: 2, score: 3}, prefix: :jt

  scope :oldest_waiting, -> { where(status: :wait) }
  scope :finished, -> { where(status: [:success, :error]) }


  belongs_to :grader_process, optional: true

  # result should be EngineResponse::Result
  def report(result)
    update(status: result.status, result: result.result_description)
  end

  def to_text
    "Job #{id} type: #{job_type}, arg: #{arg}"
  end

  #
  # ---- class method
  #

  def self.add_grade_submission_job(submission, dataset, priority)
    # just add normal compile job
    self.add_compiling_job(submission, dataset, priority)
  end

  def self.add_compiling_job(submission, dataset, priority)
    raise GraderError.new("Sub ##{submission.id} does not have live dataset",
                          submission_id: submission.id) unless dataset
    Job.create(parent_job_id: nil,
               job_type: :compile,
               arg: submission.id,
               priority: priority,
               param: {dataset_id: dataset.id}.to_json)
  end

  def self.add_evaluation_jobs(submission, dataset, parent_job_id = nil, priority = 0)
    raise GraderError.new("Sub ##{submission.id} cannot find dataset #{dataset.id}",
                          submission_id: submission.id) unless dataset
    dataset.testcases.each do |testcase|
      Job.create(parent_job_id: parent_job_id,
                 job_type: :evaluate,
                 arg: submission.id,
                 priority: priority,
                 param: {testcase_id: testcase.id}.to_json)
    end
  end

  def self.add_scoring_job(submission, dataset, parent_job_id = nil, priority = 0)
    Job.create(parent_job_id: parent_job_id,
               job_type: :score,
               arg: submission.id,
               priority: priority,
               param: {dataset_id: dataset.id}.to_json)
  end

  def self.has_waiting_job(job_type = nil)
    q = Job.where(status: :wait)
    q = q.where(job_type: job_type) unless job_type.nil?
    return q.exists?
  end

  # fetch jobs from the queue, only for given job_type, if given
  def self.take_oldest_waiting_job(grader_process, job_type = nil)
    job = nil
    Job.transaction do
      # pick non-locked oldest_waiting
      # https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-reads.html#innodb-locking-reads-nowait-skip-locked
      jobs = Job.lock("FOR UPDATE SKIP LOCKED").oldest_waiting
      jobs = jobs.where(job_type: job_type) unless job_type.nil?
      job = jobs.order('priority DESC, id ASC').first

      if job
        job.update(status: :process, grader_process: grader_process)
      end
    end
    return job
  end

  # check if all evaluation with the same parent of *job* are all finish
  def self.all_evaluate_job_complete(job)
    Job.where(parent_job_id: job.parent_job_id, job_type: :evaluate).where.not(status: :success).count == 0
  end

  # delete successful jobs older than x (errors are kept until admin clears them)
  def self.clean_old_job(x = 1.day)
    Job.where(status: :success).where('updated_at < ?', Time.zone.now - x).delete_all
  end

  #
  # ---- reclaiming orphaned jobs ----
  #

  # How long a job may sit in :process before requeueing it stops being the
  # helpful thing to do. Well above the longest legitimate single job — a
  # compile is capped at 10s (Compiler#compile) and the largest dataset
  # time_limit in production is 5s — so this is not a race window, it is the
  # point past which regrading has become a surprise rather than a repair.
  MAX_RECLAIM_AGE = 24.hours

  # Shared budget with check_and_run_job's rescue, which parses the same
  # "retry N" prefix out of #result: a job that keeps taking its grader down
  # with it must not requeue forever. Attempts 1..N-1 requeue, attempt N is
  # dead-lettered — same arithmetic as the rescue there.
  RECLAIM_ATTEMPT_LIMIT = 3

  # Return jobs whose grader claimed them and never reported back to the
  # queue. A job reaches :process in take_oldest_waiting_job and leaves it
  # only through Job#report; if the grader dies in between — OOM, kill -9, a
  # host reboot, the watchdog's stalled-KILL branch (Grader.plan_box) —
  # nothing ever flips it back. Its parent chain never completes and its
  # submission sits in :evaluating forever.
  #
  # Requeueing is safe in principle: compile, evaluate and score are all
  # re-runnable, Evaluation is find_or_create_by per (submission, testcase),
  # and Evaluator#prepare_executable re-downloads the compiled binary rather
  # than trusting whatever the judge box still has on disk. It is only
  # *meaningful*, though, while the submission is still mid-flight, so two
  # cases are dead-lettered to :error rather than requeued:
  #
  #   * the submission already reached a GRADING_FINAL_STATUS — an admin
  #     rejudged it, or a sibling chain finished it. Re-running would
  #     overwrite a settled grade, and Grader.cleanup_web has since purged
  #     the compiled binary an evaluate job would need anyway.
  #   * the job has been stuck longer than MAX_RECLAIM_AGE.
  #
  # A submission still mid-flight is marked grader_error, so it stops showing
  # "evaluating" and the ordinary admin Rejudge path applies to it.
  #
  # Two callers, deliberately different in how each proves the grader is gone:
  #   * Grader.watchdog passes grader_process_ids: for the boxes its own `ps`
  #     sweep just proved have no process running at all. No timing heuristic,
  #     so it cannot yank a job out from under a grader that is merely slow;
  #     latency is one watchdog tick. The default older_than: still applies,
  #     closing the sub-second gap between that ps snapshot and this query in
  #     which a starting grader could claim a fresh job.
  #   * a Solid Queue recurring task passes a generous older_than: as a
  #     fleet-wide backstop, for a host whose watchdog is itself not running
  #     (that is exactly when the ps-based path cannot fire).
  #
  # Returns {requeued:, abandoned:}.
  def self.reclaim_orphaned!(grader_process_ids: nil, older_than: 1.minute)
    scope = Job.where(status: :process).where('updated_at < ?', Time.zone.now - older_than)
    scope = scope.where(grader_process_id: grader_process_ids) if grader_process_ids
    stats = {requeued: 0, abandoned: 0}

    scope.includes(:grader_process).find_each do |job|
      sub = Submission.find_by(id: job.arg)
      mid_flight = sub && !Submission::GRADING_FINAL_STATUSES.include?(sub.status)
      attempt = (job.result&.match(/retry (\d+)/)&.[](1)&.to_i || 0) + 1
      reason =
        if sub.nil?
          'submission no longer exists'
        elsif !mid_flight
          "submission already #{sub.status}"
        elsif job.updated_at < Time.zone.now - MAX_RECLAIM_AGE
          "stuck since #{job.updated_at.to_fs(:db)}"
        elsif attempt >= RECLAIM_ATTEMPT_LIMIT
          "grader died on it #{attempt} times"
        end

      if reason
        job.update(status: :error, result: "reclaim gave up (#{job.grader_label}): #{reason}".truncate(255))
        sub.set_grading_error('Grading was interrupted and could not be resumed. Please rejudge.') if mid_flight
        stats[:abandoned] += 1
      else
        job.update(status: :wait, result: "retry #{attempt}: reclaimed, #{job.grader_label} died mid-job".truncate(255))
        stats[:requeued] += 1
      end
    end

    if stats.values.sum > 0
      Rails.logger.warn("[Job.reclaim_orphaned!] requeued #{stats[:requeued]}, abandoned #{stats[:abandoned]}")
    end
    stats
  end

  # Which grader claimed this job, for the reclaim message. The row survives
  # the process (find_or_create_by per worker/box in Grader#initialize), so
  # this names the box, not the dead pid.
  def grader_label
    gp = grader_process
    return 'no grader' unless gp
    "grader worker #{gp.worker_id} box #{gp.box_id}"
  end
end

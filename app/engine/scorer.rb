# This is for calculating the score of a submission after testcases are evaluated
class Scorer
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers

  def sum_of_all_subtasks
    @sub.update(score: 100)
  end

  # main run function
  # calculate the score, assuming all required evaluation is completed
  def process(sub)
    @sub = sub

    # init isolate
    # setup_isolate(@box_id)

  end

  #return appropriate evaluator class for the submission
  def self.get_scorer(submission)
    #todo: should return appropriate scorer class
    return self
  end
end

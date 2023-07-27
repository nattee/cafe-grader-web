# This is for calculating the score of a submission after testcases are evaluated
class Scorer
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers

  def sum_of_all_testcases
    sum_user_score,sum_total_score = 0.to_d,0.to_d;
    @sub.evaluations.each do |ev|
      sum_user_score += ev.score;
      sum_total_score += ev.testcase.score
    end
    score = sum_user_score / sum_total_score
    return score;
  end

  # main run function
  # calculate the score, assuming all required evaluation is completed
  def process(sub)
    @sub = sub

    point = sum_of_all_testcases
    @sub.update(points:  point)

    judge_log "Scoring of ##{@sub.id} completed with points = #{point}"

    # init isolate
    # setup_isolate(@box_id)
    return default_success_result
  end

  #return appropriate evaluator class for the submission
  def self.get_scorer(submission)
    #todo: should return appropriate scorer class
    return self
  end
end

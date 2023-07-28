# This is for calculating the score of a submission after testcases are evaluated
class Scorer
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers

  def sum_of_all_testcases
    sum_user_score,sum_total_weight = 0.to_d,0.to_d;
    @sub.evaluations.each do |ev|
      score = ev.score || 0
      weight = ev.testcase.get_weight || 0
      sum_user_score += score * weight
      sum_total_weight += weight
    end
    score = sum_user_score / sum_total_weight
    return score;
  end

  def build_grading_text
    result = ''

    #gen group info
    evs = @sub.evaluations.joins(:testcase).includes(:testcase)
      .order(:group_name,:code_name,'testcases.id ASC')

    last_group = nil
    # build the string
    evs.each do |ev|
      tc = ev.testcase

      #process group
      if last_group != tc.group
        #found new group, save old group result
        if last_group != nil

          if current_group_count == 1
            result += group_result
          else
            # multiple testcase in group
            result += '[' +  group_result + ']'
          end
        end

        #reset group tally
        group_result = ''
        current_group_count = 0
        current_group_min = nil
      end
      result += ev.result_text
    end
    return result
  end

  # main run function
  # calculate the score, assuming all required evaluation is completed
  def process(sub)
    @sub = sub

    point = sum_of_all_testcases

    grading_text = build_grading_text
    judge_log "Scoring of ##{@sub.id} completed with points = #{point} (#{grading_text})"

    #update result
    @sub.set_grading_complete(point,grading_text)

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

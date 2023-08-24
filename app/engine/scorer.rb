# This is for calculating the score of a submission after testcases are evaluated
class Scorer
  include IsolateRunner
  include JudgeBase
  include Rails.application.routes.url_helpers

  def sorted_evaluation
    @sub.evaluations.joins(:testcase).includes(:testcase)
          .order(:group_name,:code_name,'testcases.id ASC')
  end

  # return a score, full score is always 100
  def sum_of_all_testcases
    sum_user_score,sum_total_weight = 0.to_d,0.to_d;
    @sub.evaluations.each do |ev|
      score = ev.score || 0
      weight = ev.testcase.weight || 0
      sum_user_score += score * weight
      sum_total_weight += weight
    end
    score = sum_user_score / sum_total_weight * 100.to_d;
    return score;
  end

  def group_min
    evs = sorted_evaluation.select(:group_name,:score,:weight,:testcase_id).map{ |r| r.attributes.symbolize_keys }
    evs << {group_name: (evs[-1][:group_name].nil? ? 1 : nil)} #sentinel

    sum_user_score,sum_total_weight = 0.to_d,0.to_d;
    last_group = nil
    min_score = 0
    max_weight = 0
    evs.each.with_index do |ev,idx|
      group_name = ev[:group_name]
      score = ev[:score] || 0
      weight = ev[:weight] || 0

      #process group
      if last_group != group_name
        #found new group, save old group result
        # the nil group has min_score, max_weight as 0
        sum_user_score += min_score * max_weight
        sum_total_weight += max_weight

        #reset group tally
        min_score = score
        max_weight = weight
      else
        min_score = [min_score,score].min
        max_weight = [max_weight,weight].min
      end
      last_group = group_name
    end

    score = sum_user_score / sum_total_weight * 100.to_d;
    return score;
  end

  def build_grading_text
    result = ''

    #gen group info
    evs = sorted_evaluation.select(:group_name,:result_text,:testcase_id).map{ |r| r.attributes.symbolize_keys }
    evs << {group_name: (evs[-1][:group_name].nil? ? 1 : nil), result_text: ''} #sentinel

    last_group = nil
    group_result = ''
    current_group_count = 0
    # build the string
    evs.each do |ev|
      group_name = ev[:group_name]
      result_text = ev[:result_text]

      #process group
      if last_group != group_name
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
      end

      group_result += result_text
      current_group_count += 1
      last_group = group_name
    end
    return result
  end

  # main run function
  # calculate the score, assuming all required evaluation is completed
  def process(sub,dataset)
    @sub = sub
    @working_dataset = dataset

    #calculate score
    point = nil
    case @working_dataset.score_type
    when 'sum'
      point = sum_of_all_testcases
    when 'group_min'
      point = group_min
    else
    end

    grading_text = build_grading_text
    judge_log "Scoring of ##{@sub.id} completed with points = #{point} (#{grading_text})"

    #calculate time
    max_time = @sub.evaluations.pluck(:time).map { |x| x || 0 }.max
    max_mem = @sub.evaluations.pluck(:memory).map { |x| x || 0 }.max

    #update result
    @sub.set_grading_complete(point,grading_text,max_time,max_mem)

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

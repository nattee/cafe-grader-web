module SubmissionsHelper

  # The price sentence of the AI-help confirm dialog (Markdown source). `cost`
  # is what THIS requester would be charged — Llm::CommentAssist.assist_cost_for:
  # 0 for an admin asking on a student's behalf, or when the site price is 0.
  def llm_assist_price_sentence(cost)
    if cost.to_i.zero?
      'This request does not reduce the __full score__ for this problem.'
    else
      "Requesting assistance will reduce the __full score__ for this problem by #{cost} points. " \
      'If your final score for this problem does not exceed the __reduced full score__, you will receive that score. ' \
      'If your score exceeds the __reduced full score__, it will be capped at the __reduced full score__.'
    end
  end
end

class Evaluation < ApplicationRecord
  belongs_to :submission
  belongs_to :testcase
  enum result: {waiting: 0, correct: 1, wrong: 2, partial: 3, time_limit: 4, memory_limit: 5, crash: 6, unknown_error: 7, grader_error: 8}
  RESULT_CODE = %w(? P - s T M x E !)

  def self.result_enum_to_code(result)
    # convert result string to num and then to character code
    result_num = results[result]
    return '' if result_num.nil?
    RESULT_CODE[result_num]

  end

  # return word describing the result
  def result_as_word
    return Evaluation.result_enum_to_code(self.result)
  end
end

class Evaluation < ApplicationRecord
  belongs_to :submission
  belongs_to :testcase
  enum result: {waiting: 0, correct: 1, wrong: 2, partial: 3, time_limit: 4, memory_limit: 5, crash: 6, unknown_error: 7, grader_error: 8}

  def set_result_text_from_result
    rt = case result
    when 'waiting'
      '?'
    when 'correct'
      'P'
    when 'wrong'
      '-'
    when 'partial'
      's'
    when 'time_limit'
      'T'
    when 'memory_limit'
      'M'
    when 'crash'
      'x'
    when 'unknown_error'
      'E'
    when 'grader_error'
      '!'
    end

    update(result_text:rt)

    return rt
  end
end

class Evaluation < ApplicationRecord
  enum result: {waiting: 0, success: 1, wrong: 2, time_limit: 3, memory_limit: 4, crash: 5, unknown_error: 6}
end

class Evaluation < ApplicationRecord
  enum result: {success: 0, wrong: 1, time_limit: 2, memory_limit: 2, crash: 3}
end

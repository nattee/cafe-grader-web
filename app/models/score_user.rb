class ScoreUser < ApplicationRecord
  belongs_to :user
  belongs_to :dataset

  enum :status, { valid: 0,    # everything is OK now
                  invalid: 1   # the dataset has been edited, the score is now invalidated
                }
end

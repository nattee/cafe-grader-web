class Tag < ApplicationRecord
  validates :name, presence: true

  enum :kind, {normal: 0, topic: 1, llm_prompt: 2}
  has_many :problems_tags, class_name: 'ProblemTag'
  has_many :problems, through: :problems_tags
end

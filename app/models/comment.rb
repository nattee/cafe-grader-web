class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :user

  enum :kind, {hint: 0, solution: 1, comment: 2, chat_gpt: 3, deepseek: 4}

  enum :cost, {aa: 0, bb: 1}

  has_many :comment_reveals
  has_many :users_who_revealed, through: :comment_reveals, source: :user # More descriptive name

  # limit to only HINT
  HINT_KIND = self.kinds.select{ |k| k[0...4] == 'hint'}

  def to_label
    "#{kind}: #{title}"
  end

  # check if the user can acquire this comment
  # This check both the logic of commentable, the contest, and the user itself
  def acquirable_by?(user)
    # basic user logic
    return false unless user.present? && user.enabled?

    # call the specific model logic
    commentable.comment_reveal_prerequisite_satisfied?(self, user)
  end

end

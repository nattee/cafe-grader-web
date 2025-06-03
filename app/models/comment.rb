class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :user

  enum kind: {hint0: 0, hint1: 1, hint2: 2, solution: 3}

  def to_label
    "#{kind}: #{title}"
  end

end

class Announcement < ApplicationRecord
  has_one_attached :file
  belongs_to :group, optional: true

  scope :for_user, ->(user) {
    where(group: nil).or(where(group: user.groups_for_action(:submit)))
  }

  scope :published, -> { where(published: true) }
  scope :frontpage, -> { published.where(frontpage: true) }
  scope :mainpage, -> { publisehd.where(frontpage: false) }

  def self.published(contest_started = false)
    if contest_started
      where(published: true).where(frontpage: false).order(created_at: :desc)
    else
      where(published: true).where(frontpage: false).where(contest_only: false).order(created_at: :desc)
    end
  end

  def self.frontpage
    where(published: 1).where(frontpage: 1).order(created_at: :desc)
  end
end

class UserContestStat < ApplicationRecord

  belongs_to :user

  def reset_timer_and_save
    self.started_at = nil
    save
  end

end

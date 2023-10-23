class Dataset < ApplicationRecord
  belongs_to :problem

  has_many :testcases, dependent: :destroy
  has_many :submissions

  enum evaluation_type: {default: 0, #diff ignore trailing space, ignore blank line
                         exact: 1, #diff ignore nothing
                         relative: 2, #token match float relate
                         custom_cafe: 3,
                         custom_cms: 4}

  enum score_type:        {sum: 0,      # summation of all testcase, default
                           group_min: 1,
                          }, _prefix: :st

  has_one_attached :checker
  has_many_attached :managers       # additional files for compile process

  def set_default
    self.compilation_type ||= 'self_contained'
    self.evaluation_type ||= 'wdiff'
    self.score_type ||= 'sum'
    self.time_limit ||= 1
    self.memory_limit ||= 512
  end

  def get_name_for_dir
    return name unless name.blank?
    return id.to_s
  end

  def live?
    self.problem.live_dataset&.id == self.id
  end

end

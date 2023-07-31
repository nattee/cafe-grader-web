class Dataset < ApplicationRecord
  belongs_to :problem

  has_many :testcases, dependent: :destroy
  has_many :submissions

  enum evaluation_type: {wdiff: 0,
                         custom: 1}

  enum score_type:        {sum: 0,      # summation of all testcase
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

  def process_import_options(options,log)
  end

  def self.migrate_old_testcases
    Problem.all.each do |p|
      d = Dataset.create(problem: p, name: :default)
      p.testcases.update_all(dataset_id: d.id)
      p.update(live_dataset: d)
    end
  end

  def live?
    self.problem.live_dataset&.id == self.id
  end

end

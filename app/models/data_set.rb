class DataSet < ApplicationRecord
  belongs_to :problem

  has_many :testcases

  def get_name_for_dir
    return name unless name.blank?
    return id.to_s
  end

  def self.migrate_old_testcases
    Problem.all.each do |p|
      d = DataSet.create(problem: p, name: :default)
      p.testcases.update_all(data_set_id: d.id)
    end

  end

end

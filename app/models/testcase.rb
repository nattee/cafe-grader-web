class Testcase < ApplicationRecord
  belongs_to :problem
  belongs_to :data_set
  #attr_accessible :group, :input, :num, :score, :sol

  def get_name_for_dir
    return code_name unless code_name.blank?
    return num.to_s
  end

end

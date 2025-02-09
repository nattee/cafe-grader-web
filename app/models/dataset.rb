class Dataset < ApplicationRecord
  belongs_to :problem

  has_many :testcases, dependent: :destroy
  has_many :submissions

  enum evaluation_type: {default: 0, #diff ignore trailing space, ignore blank line
                         exact: 1, #diff ignore nothing
                         relative: 2, #token match float relate
                         custom_cafe: 3,
                         custom_cms: 4,
                         postgres: 5}

  enum score_type:        {sum: 0,      # summation of all testcase, default
                           group_min: 1,
                          }, _prefix: :st

  has_one_attached :checker
  has_many_attached :managers       # additional files for compile process (these files are VISIBLE to the user's submission)
  has_many_attached :initializers   # additional files for initialization of testcases
  has_many_attached :data_files     # additional files when running

  before_save :update_main_filename

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

  def set_weight(weight_param)
    tc_ids = testcases.display_order.ids
    idx = 0
    weight_param.each do |wp|
      count = 1;
      if wp.is_a? Array
        count = wp[1].to_i
        w = wp[0].to_i;
      else
        w = wp.to_i;
      end
      # take next count ids
      ids = tc_ids[idx...(idx+count)]
      idx += count
      Testcase.where(id: ids).update(weight: w)
    end
  end

  # set testcases parameters *field* by array
  def set_by_array(field, array)
    tc_ids = testcases.display_order.ids
    idx = 0
    array.each do |config|
      count = 1;
      if config.is_a? Array
        count = config[1].to_i
        value = config[0];
      else
        value = config;
      end
      # take next count ids
      ids = tc_ids[idx...(idx+count)]
      idx += count
      hash = {}
      hash[field] = value
      Testcase.where(id: ids).update(hash)
    end
  end

  def set_by_hash(options)
    set_by_array(:weight,options[:weight]) if options.has_key? :weight
    set_by_array(:group,options[:group]) if options.has_key? :group
    set_by_array(:group_name,options[:group_name]) if options.has_key? :group_name
  end

  def invalidate_worker
    WorkerDataset.where(dataset_id: @dataset).delete_all
  end

  # set main_filename if null and should be set
  # also set to null of current value is invalid
  # this DOES not save, as it is set as called back on before_save
  # return true if change were made (which means that the record should be save)
  def update_main_filename
    if managers.attached?
      manager_filenames = self.managers.map{ |x| x.filename.to_s }
      unless manager_filenames.include? main_filename
        self.main_filename = manager_filenames[0]
        return true
      end
    else
      unless self.main_filename.nil?
        self.main_filename = nil
        return true
      end
    end
    return false
  end

  protected

end

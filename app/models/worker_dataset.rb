class WorkerDataset < ApplicationRecord
  belongs_to :dataset
  #should belong to worker but we don't have the hosts table yet
  #belongs_to :worker

  enum status: {created: 0, downloading_testcase: 1, ready: 3}


end

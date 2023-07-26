class WorkerProblem < ApplicationRecord
  belongs_to :problem

  enum status: {created: 0, downloading_testcase: 1, ready: 3}

  #should belong to host but we don't have the hosts table yet
  #belongs_to :host

end

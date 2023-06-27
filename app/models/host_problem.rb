class HostProblem < ApplicationRecord
  belongs_to :problem

  #should belong to host but we don't have the hosts table yet
  #belongs_to :host

end

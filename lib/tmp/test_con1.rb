WorkerProblem.transaction do
  wp = WorkerProblem.lock("FOR UPDATE").find_or_create_by(worker_id: 1, problem_id: 345)
  puts "got #{wp.updated_at}"
  d = Date.new(ARGV[0].to_i,10,10)
  wp.update(updated_at: Date.new(1,10,10))
  puts "updated to #{d}, type something"
  sleep(10)
  d += 100.year
  wp.update(updated_at: Date.new(1,10,10))
  puts "updated to #{d}"
end


namespace :grader do
  task :migrate_to_2023 do
    puts "start migrating to 2023"
    Dataset.migrate_old_testcases
    puts "Migrate testcase done..."
  end

  task :restart do
    desc 'Stop any running graders of this worker machine and restart 4 graders'

    Grader.make_enabled(0)
    Grader.watchdog
    sleep(1)
    puts '-------------'
    Grader.make_enabled(4)
    Grader.watchdog
  end
end

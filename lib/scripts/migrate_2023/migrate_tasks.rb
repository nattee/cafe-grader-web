# iterates over all directories in ../judge/ev
# for any directory with maching problem name
#   1. import each testcases into the problem new live dataset
#   2. parse all_tests.cfg for problem info
#   3. read any manager and store in active storage
#   4. read any checker

BASE_EV_DIRECTORY = Rails.root.join '../judge/ev/*'

def import_all_testcase(prob_ev_dir,problem)
  ds = Dataset.create(problem: problem,name: 'import')

  testcases_root = ev_dir + 'test_cases'
  num = 1
  loop do
    file_root = testcases_root + "/#{num}/"
    break unless File.exists? file_root
    inp = File.read(file_root + "/input-#{num}.txt").gsub(/\r$/, '')
    ans = File.read(file_root + "/answer-#{num}.txt").gsub(/\r$/, '')
    puts "  got test case ##{num} of size #{inp.size} and #{ans.size}"

    tc = Testcase.create(num: num,weight: 10,group: num,dataset: ds)
    tc.inp_file.attach(io: StringIO.new(inp), filename: 'input.txt', content_type: 'text/plain',  identify: false)
    tc.ans_file.attach(io: StringIO.new(ans), filename: 'answer.txt', content_type: 'text/plain',  identify: false)
    num += 1
  end
  p.live_dataset = ds
  p.save
  return ds
end

# read all_test cfg file and return a hash information
def parse_all_test_cfg(filename,ds)
  on_run = false
  run = nil
  tests = nil
  scores = nil
  result = {}
  File.foreach(filename).each do |line|
    #time limit
    md = /time_limit_each\s+(\d+\.?\d*)/.match line
    result[:time_limit] = md[1].to_f if md

    # mem limit
    md = /mem_limit_each\s+(\d+\.?\d*)/.match line
    result[:mem_limit] = md[1].to_f if md

    # score_each
    md = /score_each\s+(\d+\.?\d*)/.match line
    result[:score_each] = md[1].to_f if md

    #run detect
    md = /run\s+(\d+)\s+do/.match line
    if (md && !on_run)
      run = md[1].to_i
      on_run = true
      tests = nil
      scores = nil
    end

    #test on run
    md = /tests\s+([\d,\s]*)/.match line
    if (md && on_run)
      tests = md[1].split(',').map { |x| x.to_i}
    end

    #score on run
    md = /scores\s+([\d,\s]*)/.match line
    if (md && on_run)
      scores = md[1].split(',').map { |x| x.to_i}
    end

    md = /end/.match line
    if (md && on_run)
      result[:group] = true if tests && tests.count > 1
      on_run = false
      result[run] = {tests: tests,scores: scores, errors: []}
      result[run][:errors] << "no test" unless tests
      result[run][:errors] << "no scores" unless scores
      tests.each do |num|
        ds.testcases.where(num: num).update(group: run,weight: scores[0], group_name: 'group '+run.to_s)
      end
    end
  end
  ds.memory_limit = result[:mem_limit]
  ds.time_limit =  result[:time_limit]
  ds.score_type = 'group_min' if result[:group]
  ds.save
  return result
end

def read_managers_from_ev(prob_ev_dir,ds)
  pi = ProblemImporter.new
  pi.import_dataset_from_dir(prob_ev_dir,ds.problem.name,
                             full_name: ds.problem.full_name,
                             dataset: ds,
                             do_testcase: false,
                             do_statement: false)
  pp pi.log if pi.got.count > 0
end

def read_default_checker(default_checker_file =  Rails.root.join('../judge/scripts/std-script/check') )
  return if @default_checker
  @default_checker = File.read(default_checker_file).gsub(/\r$/, '')
end

def read_checker_from_ev(prob_ev_dir,ds)
  read_default_checker
  check_file = prob_ev_dir + 'script' + 'check'
  my_checker = File.read(check_file).gsub(/\r$/, '')

  if (my_checker != @default_checker)
    byebug
    puts "Problem #{ds.problem.name} has custom checker"
  end
end


def do_dir(prob_ev_dir)
  p = Problem.where(name: prob_ev_dir.basename.to_s).first
  return unless p

  ds = p.live_dataset
  # read checker
  read_checker_from_ev(prob_ev_dir,ds)
  return

  #now p is the problem with the same name as the ev sub-dir

  # import all testcases in ev/{prob}/testcases/xxx into a new live dataset ds
  ds = import_all_testcases(prov_ev_dir,p)

  r = parse_all_test_cfg(pn + 'test_cases/all_tests.cfg',ds)
  if (r[:group])
    puts "Problem #{p.name} (#{p.id}) has grouped testcase"
  end

  #read manager
  read_managers_from_ev(prob_ev_dir,ds)

end

# for each dir  in ev
def main
  Dir[BASE_EV_DIRECTORY].each do |ev_dir|
    prob_ev_dir = Pathname.new ev_dir
    do_dir(prob_ev_dir)
  end
end

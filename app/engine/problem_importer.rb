class ProblemImporter

  attr_reader :problem, :log, :errors, :got, :dataset

  require 'open3'
  def initialize
    @got = []
    @log = []
    @options = {}
    @errors = []
  end

  def read_testcase(input_pattern, sol_pattern, code_name_regex, group_name_regex)
    # glob testcase
    @tc = Hash.new { |h,k| h[k] = Hash.new }
    Dir["#{@base_dir}/**/#{input_pattern}"].each do |fn|
      input_fn = Pathname.new(@base_dir) + fn
      regex = Regexp.new input_pattern.gsub('*','(.+)')

      #try to match the codename with the regex
      mc = input_fn.basename.to_s.match regex
      next unless mc
      name = mc[1]

      #default codename, use the part that match the wildcard
      codename = name

      #parse codename according to regex
      codename_mc = name.match code_name_regex
      codename = mc[1] if mc

      @tc[codename][:input] = input_fn.cleanpath
    end
    Dir["#{@base_dir}/**/#{sol_pattern}"].each do |fn|
      sol_fn = Pathname.new(@base_dir) + fn
      regex = Regexp.new sol_pattern.gsub('*','(.+)')
      #codename = sol_fn.basename(sol_pattern[(sol_pattern.index('*')+1)..]).to_s # default codename to the * part of the sol_pattern

      #try to match the codename with the regex
      mc = sol_fn.basename.to_s.match regex
      next unless mc
      name = mc[1]

      #default codename, use the part that match the wildcard
      codename = name

      #parse codename according to regex
      codename_mc = name.match code_name_regex
      codename = mc[1] if mc

      @tc[codename][:sol] = sol_fn.cleanpath
    end

    # load into dataset and testcase
    num = @dataset.testcases.count + 1
    group = 1
    #group_hash = Hash.new { |h,k| h[k] = [] }
    group_hash = {}

    # we sort the filename by their natural sort order
    natural_order_sorted = @tc.keys.sort_by{ |s| s.split(/[^\d]+/).map{ |e| Integer(e,10) rescue e}}
    natural_order_sorted.each do |k|
      if @tc[k].count >= 2
        # we found both the input and sol
        # the codename is the key of the hash

        #parse group_name
        group_name = group_hash.count + 1
        mg = @tc[k][:input].basename.to_s.match group_name_regex
        group_name = mg[1] if mg # if match, we will use the captured pattern

        if group_hash.has_key? group_name
          group = group_hash[group_name]
        else
          group = group_hash.count + 1
          group_hash[group_name] = group
        end

        #create new testcase
        new_tc = @dataset.testcases.where(code_name: k).first
        if new_tc
          @log << "replace existing testcase with codename #{k} (num and group are #{new_tc.num} #{new_tc.group})"
        else
          @log << "add a testcase #{num} with codename #{k} and group #{group}"
          new_tc = Testcase.new(code_name: k, num: num, group: group,weight: 1,group_name: group_name)
          num +=1
        end
        new_tc.input = File.read(@tc[k][:input]).gsub(/\r$/, '')
        new_tc.sol = File.read(@tc[k][:sol]).gsub(/\r$/, '')
        @dataset.testcases << new_tc
        @log << "  #{@tc[k][:input]} is the input"
        @log << "  #{@tc[k][:sol]} is the sol"
      end
    end

    @problem.save

  end

  def read_options
    yaml,fn = get_content_of_first_match('config.yml')
    if (yaml)
      @options = YAML.safe_load(yaml,symbolize_names: true)

      # process options for dataset
      @dataset.process_import_options(@options,@log)


      @problem.full_name = @options[:full_name] if @options.has_key? :fullname
      @problem.submission_filename = @options[:submission_filename] if @options.has_key? :submission_filename
    end
  end

  def read_statement
    # pdf
    pdf,fn = get_content_of_first_match('*.pdf')
    if pdf
      @problem.statement.attach(io: StringIO.new(pdf),filename: fn.basename)
      @log << "Found a pdf statement [#{fn}]"
      @got << fn
    else
      @log << "no pdf file is given as a statement"
    end

    # additional description
    md,fn = get_content_of_first_match('*.md')
    if (md)
      @problem.update(description: md)
      @log << "Found addtional Markdown file [#{fn}]"
      @got << fn
    end
  end


  def read_cpp_extras
    # main
    main_filename = ['main.cpp','main_grader.cpp','grader.cpp']
    main_filename = @options[:main] if @options.has_key?(:main)
    path = @options[:managers_dir] || ''
    main,fn = get_content_of_first_match(main_filename,path: path)
    if (main)
      @log << "Found the main file [#{fn}]"
      @got << fn
      # delete existing
      @dataset.managers.each { |f| f.purge if f.filename == Pathname.new(fn).basename }
      @dataset.reload

      # add new file
      @dataset.managers.attach(io: File.open(fn),filename: Pathname.new(fn).basename)
      @dataset.main_filename = Pathname.new(fn).basename
      @problem.compilation_type = 'with_managers'
      @problem.submission_filename = 'student.h'
      @problem.save
      @dataset.save
    end

    # any .h
    managers = @options[:managers] || '*.h'
    pattern = build_glob(managers,path: @options[:managers_dir] || '')
    managers_fn = {}
    Dir.glob(pattern).each do |fn|
      @log << "Found an additional manager file [#{fn}]"
      @got << fn
      basename = Pathname.new(fn).basename
      if managers_fn.has_key? basename
        @log << "  ERROR: multiple managers of the same name #{basename}"
      else
        managers_fn[basename] = true
        # delete existing
        @dataset.managers.each { |f| f.purge if f.filename == basename }
        @dataset.reload

        @dataset.managers.attach(io: File.open(fn),filename: basename)
      end
    end
    @dataset.save
  end

  def read_checker
    #glob checker
    checker,fn = get_content_of_first_match('checker.*')
    if (checker)
      @log << "Found a custom checker file [#{fn}]"
      @got << fn
      @dataset.checker.attach(io: StringIO.new(checker),filename: fn.basename)
    end
  end

  def get_content_of_first_match(glob_pattern, recursive: true,path: '')
    pattern = build_glob(glob_pattern,recursive: recursive, path: path)
    files = Dir.glob(pattern)
    if files.count > 0
      if files.count > 1
        @log << "ERROR: Found multiples of #{glob_pattern} while we expected one"
        return
      end

      full_path = Pathname.new(@base_dir) + files[0]
      return File.read(full_path.cleanpath),full_path.cleanpath
    end

    #match none
    return nil
  end

  # build glob pattern array from glob_patterns
  # add recursive path if needed
  def build_glob(glob_patterns, recursive: false, path: '')
    glob_patterns = [glob_patterns] unless glob_patterns.is_a? Array
    result = glob_patterns.map do |p|
      pattern = @base_dir.to_s + '/'
      pattern += path + '/' unless path.blank?
      pattern += '**/' if recursive
      pattern += p
      pattern
    end
    return result
  end

  # import dataset in the dir into a problem,
  # might also set it as a live dataset
  # If the problem with the same name exist, this will add another dataset
  # if *dataset* is nil, this will be imported to a new dataset
  # if not, it will override the given dataset "without deleting anything of that dataset" 
  #    a testcase with the same codename will be replaced
  def import_dataset_from_dir(dir, name,
    full_name: ,          #required keyword
    dataset: nil,         # if nil, we will create a new dataset
    delete_existing: false,
    input_pattern: '*.in',
    sol_pattern: '*.sol',
    code_name_regex: /(.*)/,       # how we get code_name from the matched wildcard
    group_name_regex: /^(\d+)-/,   # how we extract group name from codename
    memory_limit: 512,
    time_limit: 1,
    do_testcase: true,
    do_statement: true,
    do_checker: true,
    do_cpp_extras: true
  )

    # init problem and dataset
    @base_dir = dir
    @problem = Problem.find_or_create_by(name: name)
    @problem.date_added = Time.zone.now unless @problem.date_added
    @problem.full_name = full_name
    @problem.set_default_value unless @problem.id
    if dataset && dataset.problem == @problem
      @dataset = dataset
    else
      @dataset = Dataset.new(name: @problem.get_next_dataset_name, problem: @problem)
    end
    @problem.datasets.where.not(id: @dataset.id).each { |ds| ds.destroy } if delete_existing
    @problem.datasets.reload

    @dataset.memory_limit = memory_limit
    @dataset.time_limit = time_limit
    @problem.live_dataset = @dataset if delete_existing || @problem.live_dataset.nil?
    @dataset.save
    unless @problem.save
      @errors += @problem.errors.full_messages
      return
    end

    @log << "Importing dataset for #{@problem.name} (#{@problem.id})"


    read_testcase(input_pattern, sol_pattern, code_name_regex, group_name_regex) if do_testcase
    read_options
    read_statement if do_statement
    read_checker if do_checker
    read_cpp_extras if do_cpp_extras
    @problem.save
    @dataset.save
    @log << "Done successfully"

    return @log
  end

  def unzip_to_dir(file,name,dir)
    Pathname.new(dir).mkpath
    pn  = Pathname.new(dir)+name
    num = 1
    while pn.exist?
      pn  = Pathname.new(dir)+"#{name}.#{num}"
      num+=1
    end

    destination = pn.cleanpath

    cmd = "unzip #{file} -d #{destination}"
    out,err,status = Open3.capture3(cmd)
    if status.exitstatus == 0
      return destination
    else
      @errors << err
      return nil
    end
  end

end

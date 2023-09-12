class ProblemImporter

  attr_reader :problem, :log, :errors

  require 'open3'
  def initialize
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
      #codename = input_fn.basename(input_pattern[(input_pattern.index('*')+1)..].to_s) # default codename to the * part of the input_pattern
      #puts "#{fn} input codename = #{codename}"

      #try to match the codename with the regex
      mc = input_fn.basename.to_s.match regex
      next unless mc
      name = mc[1]

      #default codename, use the part that match the wildcard
      codename = name

      #parse codename according to regex
      codename_mc = name.match code_name_regex
      codename = mc[1] if mc

      puts "#{fn} input codename = #{codename}"
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

      puts "#{fn} sol codename = #{codename}"
      @tc[codename][:sol] = sol_fn.cleanpath
    end

    # load into dataset and testcase
    num = 1
    group = 1
    #group_hash = Hash.new { |h,k| h[k] = [] }
    group_hash = {}

    # we sort the filename by their natural sort order
    natural_order_sorted = @tc.keys.sort_by{ |s| s.split(/(\d+)/).map{ |e| Integer(e) rescue e}}
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
        new_tc = Testcase.new(num: num, group: group,weight: 1,group_name: group_name, code_name: k)
        new_tc.input = File.read(@tc[k][:input])
        new_tc.sol = File.read(@tc[k][:sol])
        @dataset.testcases << new_tc
        @log << "add a testcase #{num} with codename #{k} and group #{group}"
        @log << "  #{@tc[k][:input]} is the input"
        @log << "  #{@tc[k][:sol]} is the sol"

        #prepare next testcase
        num +=1
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
      @problem.statement.attach(io: StringIO.new(pdf),filename: fn)
      @log << "Found a pdf statement, [#{fn}]"
    else
      @log << "no pdf file is given as a statement"
    end

    # additional description
    md,fn = get_content_of_first_match('*.md')
    if (md)
      @problem.update(description: md)
      @log << "Found addtional Markdown file, [#{fn}]"
    end
  end


  def read_cpp_extras
    # main
    main_filename = 'main.cpp'
    main_filename = @options[:main] if @options.has_key?(:main)
    path = @options[:managers_dir] || ''
    main,fn = get_content_of_first_match(main_filename,path: path)
    if (main)
      @log << "Found the main file, [#{fn}]"
      @dataset.managers.attach(io: StringIO.new(main),filename: Pathname.new(fn).basename)
      @dataset.main_filename = Pathname.new(fn).basename
      @problem.compilation_type = 'with_managers'
    end

    # any .h
    managers = @options[:managers] || '*.h'
    pattern = build_glob(managers,path: @options[:managers_dir] || '')
    managers_fn = {}
    Dir.glob(pattern).each do |fn|
      @log << "Found additional manager file, [#{fn}]"
      basename = Pathname.new(fn).basename
      if managers_fn.has_key? basename
        @log << "  ERROR: multiple managers of the same name #{basename}"
      else
        managers_fn[basename] = true
        @dataset.managers.attach(io: File.open(fn),filename: basename)
      end
    end
  end

  def read_checker
    #glob checker
    checker,fn = get_content_of_first_match('checker.*')
    if (checker)
      @log << "Found custom checker file, [#{fn}]"
      @problem.checker.attach(io: StringIO.new(checker),filename: fn)
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
      pattern = @base_dir
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
  def import_dataset_from_dir(dir, name,
    full_name: ,          #required keyword
    set_as_live: false,
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
    do_cpp_extras: true,
  )
    Dataset.transaction do

      # init problem and dataset
      @base_dir = dir
      @problem = Problem.find_or_create_by(name: name)
      @problem.date_added = Time.zone.now unless @problem.date_added
      @problem.full_name = full_name
      @problem.set_default_value unless @problem.id
      @dataset = Dataset.new(name: @problem.get_next_dataset_name)
      @dataset.memory_limit = memory_limit
      @dataset.time_limit = time_limit
      @problem.datasets.each { |ds| ds.destroy } if delete_existing
      @problem.datasets << @dataset
      @problem.live_dataset = @dataset if set_as_live || @problem.datasets.count == 0
      @problem.save
      @dataset.save

      @log << "Importing dataset for #{@problem.name} (#{@problem.id})"

      read_testcase(input_pattern, sol_pattern, code_name_regex, group_name_regex)
      read_options
      read_statement
      read_checker
      read_cpp_extras
      @problem.save
      @dataset.save
      @log << "Done successfully"
    end

    return @log
  end

  def unzip_to_dir(file,name,dir)
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

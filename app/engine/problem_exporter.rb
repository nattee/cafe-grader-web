class ProblemExporter

  require 'open3'

  STATEMENT_FN = 'statement.pdf'
  INP_EXT = 'in'
  ANS_EXT = 'sol'


  def initialize
    @log = []
    @options = {}
    @inp_ext = INP_EXT
    @ans_ext = ANS_EXT
  end

  def export_pdf
    return unless @problem.statement.attached?
    @statement_filename = @main_dir + STATEMENT_FN;
    @statement_filename.dirname.mkpath

    File.open(@statement_filename,'w:ASCII-8BIT') do |f|
      @problem.statement.download { |chunk| f.write(chunk) }
    end
  end

  def export_testcases
    @testcase_dir = @main_dir + 'testcases'
    @testcase_dir.mkpath
    @ds.testcases.each do |tc|
      inp_fn = @testcase_dir + "#{tc.code_name || tc.num}.#{@inp_ext}"
      ans_fn = @testcase_dir + "#{tc.code_name || tc.num}.#{@ans_ext}"

      File.open(inp_fn,'w:ASCII-8BIT') do |f|
        tc.inp_file.download { |chunk| f.write(chunk) }
      end
      File.open(ans_fn,'w:ASCII-8BIT') do |f|
        tc.ans_file.download { |chunk| f.write(chunk) }
      end
    end
  end

  def export_managers_checker
    @manager_dir = @main_dir + 'managers'
    @manager_dir.mkpath
    @ds.managers.each do |mng|
      filename = @manager_dir + mng.filename.to_s
      File.open(filename,'w:ASCII-8BIT') { |f| mng.download { |chunk| f.write chunk } }
      @options[:managers_pattern] = '*'
    end

    if @ds.checker.attached?
      @checker_dir = @main_dir + 'checker'
      @checker_dir.mkpath
      @checker_filename = @checker_dir + 'checker'
      File.open(@checker_filename,'w:ASCII-8BIT') { |f| @ds.checker.download { |chunk| f.write chunk } }
      @options[:checker] = @checker_filename.basename
      @options[:checker_dir] = @checker_filename.dirname
    end
  end

  def export_options
    #problem value
    p_options = %i(name full_name submission_filename task_type compilation_type permitted_lang)
    p_options.each do |opt| 
      @options[opt] = @problem.send(opt) unless @problem.send(opt).blank?
      @options[opt] = @options[opt].to_f if @options[opt].is_a? BigDecimal 
    end

    #live dataset value
    d_options = %i(time_limit memory_limit score_type evaluation_type main_filename)
    d_options.each do |opt|
      @options[opt] = @ds.send(opt) unless @ds.send(opt).blank?
      @options[opt] = @options[opt].to_f if @options[opt].is_a? BigDecimal 
    end
    @options[:ds_name] = @ds.name

    #managers, checker
    @options[:managers_dir] = 'managers'
    @options[:checker_dir] = 'checker'

    # tags
    @options[:tags] = @problem.tags.pluck :name if @problem.tags.count > 0

    # allowed_
    config_filename = @main_dir + 'config.yml'
    #we need to stringify, else the YAML.safe_load won't work directly
    File.write(config_filename,@options.stringify_keys.to_yaml)
  end

  # this export the problem and its live dataset to a dir
  # with the name of the problem into *base_dir*
  def export_problem_to_dir(problem, base_dir)
    @problem = problem
    @ds = @problem.live_dataset
    raise 'No live dataset' unless @ds

    @main_dir = Pathname.new(base_dir) + problem.name

    export_pdf

    export_testcases

    export_managers_checker

    export_options
  end

  def self.dump_problems(probs = Problem.available, base_dir = Rails.root.join('../judge/dump') )
    probs.each do |p|
      pi = ProblemExporter.new
      pi.export_problem_to_dir(p,base_dir)
      puts "dump #{p.name} to #{base_dir}"
    end
  end


end

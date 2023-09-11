require 'open3'

module IsolateRunner
  MetaFilename = 'meta.json'

  def setup_isolate(box_id,cg = false)
    @isolate_cmd = Rails.configuration.worker.isolate_path
    @box_id = box_id

    cmd = "#{@isolate_cmd} --init #{'--cg' if cg} -b #{@box_id}"
    judge_log "ISOLATE setup command: #{cmd}", Logger::DEBUG
    out,err,status = Open3.capture3(cmd)
  end

  #  Run isolate,
  #  time_limit, wall_limit are in second, fractional is allowed
  #  mem_limit is in MB
  #  time_limit is in sec
  def run_isolate(prog,input: {},output: {},time_limit: 1, wall_limit: time_limit + 0.5,mem_limit: 1024, isolate_args: [], meta: MetaFilename, cg: false)
    #mount directory for input /output
    dir_args = []
    output.each { |k,v| dir_args << ['-d',"#{k}=#{v}:rw"] } #these are mounted read/write
    input.each { |k,v| dir_args << ['-d',"#{k}=#{v}"] }     #these are mounted readonly

    limit_arg = "-t #{time_limit} -x #{wall_limit} #{cg ? '--cg-mem' : '-m'} #{mem_limit * 1024}"
    all_arg  = "#{limit_arg} #{dir_args.join ' '} #{isolate_args.join ' '}"

    cmd = "#{@isolate_cmd} #{'--cg' if cg} --run -b #{@box_id} --meta=#{meta} #{all_arg} -- #{prog}"
    judge_log("ISOLATE run command: #{cmd}", Logger::DEBUG)
    out,err,status = Open3.capture3(cmd)
    judge_log("ISOLATE run completed: status #{status}, stdout size = #{out.length}", Logger::DEBUG)

    return out,err,status,parse_meta(meta)
  end

  def cleanup_isolate
    cmd = "#{@isolate_cmd} --cleanup -b #{@box_id}"
    judge_log "ISOLATE cleanup command: #{cmd}", Logger::DEBUG
    system(cmd)
  end

  # load the filename and parse it
  # return a hash
  def parse_meta(filename)
    result = Hash.new
    File.open(filename,'r').each do |line|
      a,b = line.split(':')
      case a
      when 'exitcode'
        result[a] = b.to_i
      when 'status','message'
        result[a] = b.strip
      else
        result[a] = b.to_d
      end
    end
    return result
  end

end

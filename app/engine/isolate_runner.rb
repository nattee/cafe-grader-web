require 'open3'

module IsolateRunner
  MetaFilename = 'meta.json'

  def setup_isolate(box_id)
    @isolate_cmd = Rails.configuration.worker.isolate_path
    @box_id = box_id

    cmd = "#{@isolate_cmd} --init -b #{@box_id}"
    judge_log "ISOLATE setup command: #{cmd}", Logger::DEBUG
    out,err,status = Open3.capture3(cmd)
  end

  def run_isolate(prog,input: {},output: {},time_limit: 1, wall_limit: time_limit + 3,isolate_args: [], meta: MetaFilename)
    #mount directory for output
    dir_args = []
    output.each { |k,v| dir_args << ['-d',"#{k}=#{v}:rw"] }
    input.each { |k,v| dir_args << ['-d',"#{k}=#{v}"] }

    cmd = "#{@isolate_cmd} --run -b #{@box_id} --meta=#{meta} #{dir_args.join ' '} #{isolate_args.join ' '} -- #{prog}"
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
      result[a] = b.to_d
      result[a] = b.to_i if a == 'exitcode'
    end
    return result
  end

end

require 'open3'

module IsolateRunner
  def setup_isolate(box_id)
    @isolate_cmd = Rails.configuration.worker.isolate_path
    @box_id = box_id

    cmd = "#{@isolate_cmd} --init -b #{@box_id}"
    puts cmd
    system(cmd)
  end

  def run_isolate(prog,input: {},output: {},time_limit: 1, wall_limit: time_limit + 3,isolate_args: [])
    #mount directory for output
    args = []
    output.each { |k,v| args << ['-d',"#{k}=#{v}:rw"] }
    input.each { |k,v| args << ['-d',"#{k}=#{v}"] }

    cmd = "#{@isolate_cmd} --run -b #{@box_id} #{args.join ' '} #{isolate_args.join ' '} -- #{prog}"
    puts cmd
    out,err,status = Open3.capture3(cmd)

    return out,err,status
  end

  def cleanup_isolate
    cmd = "#{@isolate_cmd} --cleanup -b #{@box_id}"
    system(cmd)
  end

end

require 'csv'

class ReportController < ApplicationController

  before_action :check_valid_login

  before_action :admin_authorization, except: [:problem_hof]

  before_action(only: [:problem_hof]) { |c|
    return false unless check_valid_login

    admin_authorization unless GraderConfiguration["right.user_view_submission"]
  }

  def max_score
  end

  # post max_score
  def show_max_score
    #process parameters
    #problems
    @problems = []
    prob_use = params[:probs][:use] rescue ''
    if prob_use == 'prob_ids'
      @problems = Problem.where(id: params[:problem_id])
    elsif prob_use == 'prob_groups'
      ids = Group.where(id: params[:prob_group_id]).joins(:problems).pluck(:problem_id).uniq
      @problems = Problem.where(id: ids)
    elsif prob_use == 'prob_tags'
      ids = Tag.where(id: params[:prob_tag_id]).joins(:problems).pluck(:problem_id).uniq
      @problems = Problem.where(id: ids)
    end


    #users
    @users = if params[:users] == "group" then 
               Group.find(params[:group_id]).users.all
             elsif params[:users] == 'enabled'
               User.includes(:contests).includes(:contest_stat).where(enabled: true)
             else
               User.includes(:contests).includes(:contest_stat)
             end

    max_records = Submission.where(user_id: @users.ids, problem_id: @problems.ids).group('user_id,problem_id')
      .select('MAX(submissions.points) as max_score, user_id,problem_id')
    max_records = submission_in_range(max_records,params[:sub_range])

    records = submission_in_range(Submission.all,params[:sub_range]).joins("JOIN (#{max_records.to_sql}) MAX_RECORD ON " +
                               'submissions.points = MAX_RECORD.max_score AND ' +
                               'submissions.user_id = MAX_RECORD.user_id AND ' +
                               'submissions.problem_id = MAX_RECORD.problem_id ').joins(:user).joins(:problem)
      .select('users.id,users.login,users.full_name,users.remark')
      .select('problems.name')
      .select('max_score')
      .select('submitted_at')

    @show_time = params['show-time'] == 'on'

    #calculate the score
    @result = calculate_max_score(records,@problems,@users)

    # this only render as turbo stream
    # see show_max_score.turbo_stream
  end

  def login
  end

  def login_summary_query
    @users = Array.new
    @since_time = Time.zone.parse( params[:since_datetime] ) || Time.zone.now rescue Time.zone.now
    @until_time = Time.zone.parse( params[:until_datetime] ) || DateTime.new(3000,1,1) rescue DateTime.new(3000,1,1)
    record = User
      .left_outer_joins(:logins).group('users.id')
      .where("logins.created_at >= ? AND logins.created_at <= ?",@since_time, @until_time)
    case params[:users]
    when 'enabled'
      record = record.where(enabled: true)
    when 'group'
      record = record.joins(:groups).where(groups: {id: params[:groups]}) if params[:groups]
    end

    record = record.pluck("users.id,users.login,users.full_name,count(logins.created_at),min(logins.created_at),max(logins.created_at)")
    record.each do |user|
      query = Login.where("user_id = ? AND created_at >= ? AND created_at <= ?",user[0],@since_time,@until_time)
      ips =  query.pluck(:ip_address).uniq
      cookie = query.pluck(:cookie).uniq

      @users << { id: user[0],
                   login: user[1],
                   full_name: user[2],
                   count: user[3],
                   min: user[4].in_time_zone,
                   max: user[5].in_time_zone,
                   ip: ips,
                   cookie: cookie
                 }
    end
  end

  def login_detail_query
    @logins = Array.new
    @since_time = Time.zone.parse( params[:since_datetime] ) || Time.zone.now rescue Time.zone.now
    @until_time = Time.zone.parse( params[:until_datetime] ) || DateTime.new(3000,1,1) rescue DateTime.new(3000,1,1)

    @logins = Login.includes(:user).where("logins.created_at >= ? AND logins.created_at <= ?",@since_time, @until_time)
    case params[:users]
    when 'enabled'
      @logins = @logins.where(users: {enabled: true})
    when 'group'
      @logins = @logins.joins(user: :groups).where(user: {groups: {id: params[:groups]}}) if params[:groups]
    end
  end

  def submission
  end

  def submission_query
    @submissions = Submission
      .joins(:problem).joins(:language).joins(user: :groups).group('submissions.id')
      #.includes(:problem).includes(:user).includes(:language)
    @submissions = submission_in_range(@submissions,params[:sub_range])

    case params[:users]
    when 'enabled'
      @submissions = @submissions.where(users: {enabled: true})
    when 'group'
      @submissions = @submissions.where(users: {groups: {id: params[:groups]}}) if params[:groups]
    end

    case params[:problems]
    when 'enabled'
      @submissions = @submissions.where(problems: {available: true})
    when 'selected'
      @submissions = @submissions.where(problem_id: params[:problem_id])
    end

    @submissions.limit(100_000)
    @submissions = @submissions.select('submissions.id,points,ip_address,submitted_at,grader_comment')
      .select('users.login, users.full_name as user_full_name, users.id as user_id')
      .select('problems.full_name, problems.name, problems.id as problem_id')
      .select('languages.pretty_name')
  end

  def progress
  end

  def progress_query
  end

  def problem_hof
    # gen problem list
    @user = User.find(session[:user_id])
    @problems = @user.available_problems

    # get selected problems or the default
    if params[:id]
      begin
        @problem = Problem.available.find(params[:id])
      rescue
        redirect_to action: :problem_hof
        flash[:notice] = 'Error: submissions for that problem are not viewable.'
        return
      end
    end

    return unless @problem

    #model submisssion
    @model_subs = Submission.where(problem: @problem,tag: Submission.tags[:model])


    #calculate best submission
    @by_lang = {} #aggregrate by language

    range =65
    #@histogram = { data: Array.new(range,0), summary: {} }
    @summary = {count: 0, solve: 0, attempt: 0}
    user = Hash.new(0)
    Submission.where(problem_id: @problem.id).includes(:language).each do |sub|
      #histogram
      d = (DateTime.now.in_time_zone - sub.submitted_at) / 24 / 60 / 60
      #@histogram[:data][d.to_i] += 1 if d < range

      next unless sub.points
      @summary[:count] += 1
      user[sub.user_id] = [user[sub.user_id], (sub.points >= 100) ? 1 : 0].max

      #lang = Language.find_by_id(sub.language_id)
      lang = sub.language
      next unless lang
      next unless sub.points >= 100

      #initialize
      unless @by_lang.has_key?(lang.pretty_name)
        @by_lang[lang.pretty_name] = {
          runtime: { avail: false, value: 2**30-1 },
          memory: { avail: false, value: 2**30-1 },
          length: { avail: false, value: 2**30-1 },
          first: { avail: false, value: DateTime.new(3000,1,1) }
        }
      end

      if sub.max_runtime and sub.max_runtime < @by_lang[lang.pretty_name][:runtime][:value]
        @by_lang[lang.pretty_name][:runtime] = { avail: true, user_id: sub.user_id, value: sub.max_runtime, sub_id: sub.id }
      end

      if sub.peak_memory and sub.peak_memory < @by_lang[lang.pretty_name][:memory][:value]
        @by_lang[lang.pretty_name][:memory] = { avail: true, user_id: sub.user_id, value: sub.peak_memory, sub_id: sub.id }
      end

      if sub.submitted_at and sub.submitted_at < @by_lang[lang.pretty_name][:first][:value] and sub.user and
          !sub.user.admin?
        @by_lang[lang.pretty_name][:first] = { avail: true, user_id: sub.user_id, value: sub.submitted_at, sub_id: sub.id }
      end

      if @by_lang[lang.pretty_name][:length][:value] > (sub.source.length || 2**30-1)
        @by_lang[lang.pretty_name][:length] = { avail: true, user_id: sub.user_id, value: (sub.source.length || 2**30-1) , sub_id: sub.id }
      end
    end

    #process user_id
    @by_lang.each do |lang,prop|
      prop.each do |k,v|
        v[:user] = User.exists?(v[:user_id]) ? User.find(v[:user_id]).full_name : "(NULL)"
      end
    end

    #sum into best
    if @by_lang and @by_lang.first
      @best = @by_lang.first[1].clone
      @by_lang.each do |lang,prop|
        if @best[:runtime][:value] >= prop[:runtime][:value]
          @best[:runtime] = prop[:runtime]
          @best[:runtime][:lang] = lang
        end
        if @best[:memory][:value] >= prop[:memory][:value]
          @best[:memory] = prop[:memory]
          @best[:memory][:lang] = lang
        end
        if @best[:length][:value] >= prop[:length][:value]
          @best[:length] = prop[:length]
          @best[:length][:lang] = lang
        end
        if @best[:first][:value] >= prop[:first][:value]
          @best[:first] = prop[:first]
          @best[:first][:lang] = lang
        end
      end
    end

    #@histogram[:summary][:max] = [@histogram[:data].max,1].max
    @summary[:attempt] = user.count
    user.each_value { |v| @summary[:solve] += 1 if v == 1 }


    #for new graph
    @chart_dataset = @problem.get_jschart_history.to_json.html_safe
  end

  def stuck #report struggling user,problem
    # init
    user,problem = nil
    solve = true
    tries = 0
    @struggle = Array.new
    record = {}
    Submission.includes(:problem,:user).order(:problem_id,:user_id).find_each do |sub|
      next unless sub.problem and sub.user
      if user != sub.user_id or problem != sub.problem_id
        @struggle << { user: record[:user], problem: record[:problem], tries: tries } unless solve
        record = {user: sub.user, problem: sub.problem}
        user,problem = sub.user_id, sub.problem_id
        solve = false
        tries = 0
      end
      if sub.points >= 100
        solve = true
      else
        tries += 1
      end
    end
    @struggle.sort!{|a,b| b[:tries] <=> a[:tries] }
    @struggle = @struggle[0..50]
  end


  def multiple_login
    #user with multiple IP
    raw = Submission.joins(:user).joins(:problem).where("problems.available != 0").group("login,ip_address").order(:login)
    last,count = 0,0
    first = 0
    @users = []
    raw.each do |r|
      if last != r.user.login
        count = 1
        last = r.user.login
        first = r
      else
        @users << first if count == 1
        @users << r
        count += 1
      end
    end

    #IP with multiple user
    raw = Submission.joins(:user).joins(:problem).where("problems.available != 0").group("login,ip_address").order(:ip_address)
    last,count = 0,0
    first = 0
    @ip = []
    raw.each do |r|
      if last != r.ip_address
        count = 1
        last = r.ip_address
        first = r
      else
        @ip << first if count == 1
        @ip << r
        count += 1
      end
    end
  end

  def cheat_report
    date_and_time = '%Y-%m-%d %H:%M'
    begin
      md = params[:since_datetime].match(/(\d+)-(\d+)-(\d+) (\d+):(\d+)/)
      @since_time = Time.zone.local(md[1].to_i,md[2].to_i,md[3].to_i,md[4].to_i,md[5].to_i)
    rescue
      @since_time = Time.zone.now.ago( 90.minutes)
    end
    begin
      md = params[:until_datetime].match(/(\d+)-(\d+)-(\d+) (\d+):(\d+)/)
      @until_time = Time.zone.local(md[1].to_i,md[2].to_i,md[3].to_i,md[4].to_i,md[5].to_i)
    rescue
      @until_time = Time.zone.now
    end

    #multi login
    @ml = Login.joins(:user).where("logins.created_at >= ? and logins.created_at <= ?",@since_time,@until_time).select('users.login,count(distinct ip_address) as count,users.full_name').group("users.id").having("count > 1")

    st = <<-SQL
  SELECT l2.*
    FROM logins l2 INNER JOIN
    (SELECT u.id,COUNT(DISTINCT ip_address) as count,u.login,u.full_name
      FROM logins l
      INNER JOIN users u ON l.user_id =  u.id
      WHERE l.created_at >= '#{@since_time.in_time_zone("UTC")}' and l.created_at <= '#{@until_time.in_time_zone("UTC")}'
      GROUP BY u.id
      HAVING count > 1
    ) ml ON l2.user_id = ml.id
    WHERE l2.created_at >= '#{@since_time.in_time_zone("UTC")}' and l2.created_at <= '#{@until_time.in_time_zone("UTC")}'
UNION
  SELECT l2.*
    FROM logins l2 INNER JOIN
    (SELECT l.ip_address,COUNT(DISTINCT u.id) as count
      FROM logins l
      INNER JOIN users u ON l.user_id =  u.id
      WHERE l.created_at >= '#{@since_time.in_time_zone("UTC")}' and l.created_at <= '#{@until_time.in_time_zone("UTC")}'
      GROUP BY l.ip_address
      HAVING count > 1
    ) ml on ml.ip_address = l2.ip_address
    INNER JOIN users u ON l2.user_id = u.id
    WHERE l2.created_at >= '#{@since_time.in_time_zone("UTC")}' and l2.created_at <= '#{@until_time.in_time_zone("UTC")}'
ORDER BY ip_address,created_at
              SQL
    @mld = Login.find_by_sql(st)

    st = <<-SQL
  SELECT s.id,s.user_id,s.ip_address,s.submitted_at,s.problem_id
    FROM submissions s INNER JOIN
    (SELECT u.id,COUNT(DISTINCT ip_address) as count,u.login,u.full_name
      FROM logins l
      INNER JOIN users u ON l.user_id =  u.id
      WHERE l.created_at >= ? and l.created_at <= ?
      GROUP BY u.id
      HAVING count > 1
    ) ml ON s.user_id = ml.id
    WHERE s.submitted_at >= ? and s.submitted_at <= ?
UNION
  SELECT s.id,s.user_id,s.ip_address,s.submitted_at,s.problem_id
    FROM submissions s INNER JOIN
    (SELECT l.ip_address,COUNT(DISTINCT u.id) as count
      FROM logins l
      INNER JOIN users u ON l.user_id =  u.id
      WHERE l.created_at >= ? and l.created_at <= ?
      GROUP BY l.ip_address
      HAVING count > 1
    ) ml on ml.ip_address = s.ip_address
    WHERE s.submitted_at >= ? and s.submitted_at <= ?
ORDER BY ip_address,submitted_at
            SQL
    @subs = Submission.joins(:problem).find_by_sql([st,@since_time,@until_time,
                                       @since_time,@until_time,
                                       @since_time,@until_time,
                                       @since_time,@until_time])

  end

  def cheat_scrutinize
    #convert date & time
    date_and_time = '%Y-%m-%d %H:%M'
    begin
      md = params[:since_datetime].match(/(\d+)-(\d+)-(\d+) (\d+):(\d+)/)
      @since_time = Time.zone.local(md[1].to_i,md[2].to_i,md[3].to_i,md[4].to_i,md[5].to_i)
    rescue
      @since_time = Time.zone.now.ago( 90.minutes)
    end
    begin
      md = params[:until_datetime].match(/(\d+)-(\d+)-(\d+) (\d+):(\d+)/)
      @until_time = Time.zone.local(md[1].to_i,md[2].to_i,md[3].to_i,md[4].to_i,md[5].to_i)
    rescue
      @until_time = Time.zone.now
    end

    #convert sid
    @sid = params[:SID].split(/[,\s]/) if params[:SID]
    unless @sid and @sid.size > 0
      return 
      redirect_to actoin: :cheat_scrutinize
      flash[:notice] = 'Please enter at least 1 student id'
    end
    mark = Array.new(@sid.size,'?')
    condition = "(u.login = " + mark.join(' OR u.login = ') + ')'

    @st = <<-SQL
  SELECT l.created_at as submitted_at ,-1 as id,u.login,u.full_name,l.ip_address,"" as problem_id,"" as points,l.user_id
  FROM logins l INNER JOIN users u on l.user_id  = u.id
  WHERE l.created_at >= ? AND l.created_at <= ? AND #{condition}
UNION
  SELECT s.submitted_at,s.id,u.login,u.full_name,s.ip_address,s.problem_id,s.points,s.user_id
  FROM submissions s INNER JOIN users u ON s.user_id = u.id
  WHERE s.submitted_at >= ? AND s.submitted_at <= ? AND #{condition}
ORDER BY submitted_at
  SQL
    
    p = [@st,@since_time,@until_time] + @sid + [@since_time,@until_time] + @sid
    @logs = Submission.joins(:problem).find_by_sql(p)





  end

  protected

  def submission_in_range(query,range_params)
    if range_params[:use] ==  'sub_id'
      #use sub id
      since_id = range_params.fetch(:from_id,0).to_i
      until_id = range_params.fetch(:to_id,0).to_i
      query = query.where('submissions.id >= ?',range_params[:from_id]) if since_id > 0
      query = query.where('submissions.id <= ?',range_params[:to_id]) if until_id > 0
    else
      #use sub time
      since_time = Time.zone.parse( range_params[:from_time] ) || Time.zone.now rescue Time.zone.now
      until_time = Time.zone.parse( range_params[:to_time] ) || Time.zone.now rescue Time.zone.now
      datetime_range= since_time..until_time
      query = query.where(submitted_at: datetime_range)
    end
    return query
  end

  def calculate_max_score(records,problems,users)
    result = {score: Hash.new { |h,k| h[k] = {} }, stat: Hash.new {|h,k| h[k] = { zero: 0, partial: 0, full: 0, sum: 0 } } }
    users.each do |u|
      result[:score][u.login]['id'] = u.id;
      result[:score][u.login]['full_name'] = u.full_name;
      result[:score][u.login]['remark'] = u.remark;
    end
    records.each do |score|
      #result[:score][score.login]['id'] = score.id
      #result[:score][score.login]['full_name'] = score.full_name
      result[:score][score.login]['prob_'+score.name] = score.max_score || 0
      unless (result[:score][score.login]['time'+score.name] || Date.new) > score.submitted_at
        result[:score][score.login]['time'+score.name] = score.submitted_at
      end
    end

    # aggregation
    result[:score].each do |k,v|
      v.each do |k2,v2|
        if k2[0..4] == 'prob_'
          #v2 is the score
          prob_name = k2[5...]
          result[:stat][prob_name][:sum] += v2 || 0
          if v2 == 0
            result[:stat][prob_name][:zero] += 1
          elsif v2 == 100
            result[:stat][prob_name][:full] += 1
          else
            result[:stat][prob_name][:partial] += 1
          end
        end
      end
    end

    # summary graph result
    count = {zero: [], partial: [], full: []}
    problems.each do |p|
      count[:zero] << result[:stat][p.name][:zero]
      count[:full] << result[:stat][p.name][:full]
      count[:partial] << result[:stat][p.name][:partial]
    end
    result[:count] = count
    return result
  end

  def gen_csv_from_scorearray(scorearray,problem)
    CSV.generate do |csv|
      #add header
      header = ['User','Name', 'Activated?', 'Logged in', 'Contest']
      problem.each { |p| header << p.name }
      header += ['Total','Passed']
      csv << header
      #add data
      scorearray.each do |sc|
        total = num_passed = 0
        row = Array.new
        sc.each_index do |i|
          if i == 0
            row << sc[i].login
            row << sc[i].full_name
            row << sc[i].activated
            row << (sc[i].try(:contest_stat).try(:started_at)!=nil ? 'yes' : 'no')
            row << sc[i].contests.collect {|c| c.name}.join(', ')
          else
            row << sc[i][0]
            total += sc[i][0]
            num_passed += 1 if sc[i][1]
          end
        end
        row << total 
        row << num_passed
        csv << row
      end
    end
  end

end

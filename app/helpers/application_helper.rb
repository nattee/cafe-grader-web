# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper

  # render material design icon
  def mdi(icon,class_name = '')
    "<span class='mi mi-bs #{class_name}'>#{icon}</span>".html_safe
  end

  #new bootstrap header
  def navbar_user_header
    left_menu = ''
    right_menu = ''
    user = User.find(session[:user_id])

    if (user!=nil) and (GraderConfiguration.show_tasks_to?(user))
      left_menu << add_menu("#{I18n.t 'menu.tasks'}", 'tasks', 'list')
      left_menu << add_menu("#{I18n.t 'menu.submissions'}", 'main', 'submission')
      left_menu << add_menu("#{I18n.t 'menu.test'}", 'test', 'index')
    end

    if GraderConfiguration['right.user_hall_of_fame']
      left_menu << add_menu("#{I18n.t 'menu.hall_of_fame'}", 'report', 'problem_hof')
    end

    right_menu << add_menu("#{content_tag(:span,'',class: 'glyphicon glyphicon-question-sign')}".html_safe, 'main', 'help')
    right_menu << add_menu("#{content_tag(:span,'',class: 'glyphicon glyphicon-comment')}".html_safe, 'messages', 'list', {title: I18n.t('menu.messages'), data: {toggle: 'tooltip'}})
    if GraderConfiguration['system.user_setting_enabled']
      right_menu << add_menu("#{content_tag(:span,'',class: 'glyphicon glyphicon-cog')}".html_safe, 'users', 'index', {title: I18n.t('menu.settings'), data: {toggle: 'tooltip'}})
    end
    right_menu << add_menu("#{content_tag(:span,'',class: 'glyphicon glyphicon-log-out')} #{user.full_name}".html_safe, 'main', 'login', {title: I18n.t('menu.log_out'), data: {toggle: 'tooltip'}})


    result = content_tag(:ul,left_menu.html_safe,class: 'nav navbar-nav') + content_tag(:ul,right_menu.html_safe,class: 'nav navbar-nav navbar-right')
  end

  def add_menu(title, controller, action, html_option = {})
    link_option = {controller: controller, action: action}
    html_option[:class] = (html_option[:class] || '') + " active" if current_page?(link_option)
    content_tag(:li, link_to(title,link_option),html_option)
  end

  def user_header
    menu_items = ''
    user = User.find(session[:user_id])

    if (user!=nil) and (session[:admin]) 
      # admin menu
      menu_items << "<b>Administrative task:</b> "
      append_to menu_items, '[Announcements]', 'announcements', 'index'
      append_to menu_items, '[Msg console]', 'messages', 'console'
      append_to menu_items, '[Problems]', 'problems', 'index'
      append_to menu_items, '[Users]', 'user_admin', 'index'
      append_to menu_items, '[Results]', 'user_admin', 'user_stat'
      append_to menu_items, '[Report]', 'report', 'multiple_login'
      append_to menu_items, '[Graders]', 'graders', 'list'
      append_to menu_items, '[Contests]', 'contest_management', 'index'
      append_to menu_items, '[Sites]', 'sites', 'index'
      append_to menu_items, '[System config]', 'configurations', 'index'
      menu_items << "<br/>"
    end

    # main page
    append_to menu_items, "[#{I18n.t 'menu.main'}]", 'main', 'list'
    append_to menu_items, "[#{I18n.t 'menu.messages'}]", 'messages', 'list'

    if (user!=nil) and (GraderConfiguration.show_tasks_to?(user))
      append_to menu_items, "[#{I18n.t 'menu.tasks'}]", 'tasks', 'list'
      append_to menu_items, "[#{I18n.t 'menu.submissions'}]", 'main', 'submission'
      append_to menu_items, "[#{I18n.t 'menu.test'}]", 'test', 'index'
    end

    if GraderConfiguration['right.user_hall_of_fame']
      append_to menu_items, "[#{I18n.t 'menu.hall_of_fame'}]", 'report', 'problem_hof'
    end
    append_to menu_items, "[#{I18n.t 'menu.help'}]", 'main', 'help'

    if GraderConfiguration['system.user_setting_enabled']
      append_to menu_items, "[#{I18n.t 'menu.settings'}]", 'users', 'index'
    end
    append_to menu_items, "[#{I18n.t 'menu.log_out'}]", 'main', 'login'

    menu_items.html_safe
  end

  def append_to(option,label, controller, action)
    option << ' ' if option!=''
    option << link_to_unless_current(label,
                                     :controller => controller,
                                     :action => action)
  end

  def format_short_time(time)
    now = Time.zone.now
    st = ''
    if (time.yday != now.yday) or (time.year != now.year)
      st = time.strftime("%d/%m/%y ")
    end
    st + time.strftime("%X")
  end

  def format_short_duration(duration)
    return '' if duration==nil
    d = duration.to_f
    return Time.at(d).gmtime.strftime("%X")
  end

  def format_full_time_ago(time)
    st = time_ago_in_words(time) + ' ago (' + format_short_time(time) + ')'
  end

  # display start and stop time in humanized way
  def format_start_stop(start,stop)
    start_text = start.strftime("%y-%b-%d %H:%M")
    date_diff = (stop.to_date - start.to_date).to_i
    end_text = stop.strftime("%H:%M")
    end_text += " (+#{pluralize(date_diff,'day')})" if (date_diff > 0)
    return "#{start_text} to #{end_text}"
  end

  def read_textfile(fname,max_size=2048)
    begin
      File.open(fname).read(max_size)
    rescue
      nil
    end
  end

  def toggle_button(on,toggle_url,id, option={})
    btn_size = option[:size] || 'btn-sm'
    btn_block = option[:block] || 'btn-block'
    link_to (on ? "Yes" : "No"), toggle_url,
      {class: "btn #{btn_block} #{btn_size} btn-#{on ? 'success' : 'outline-secondary'} ajax-toggle",
        id: id,
        data: {remote: true, method: 'get'}}
  end

  def get_ace_mode(language)
    # return ace mode string from Language

    return 'ace/mode/c_cpp' unless language
    case language.pretty_name
      when 'Pascal'
        'ace/mode/pascal'
      when 'C++','C'
        'ace/mode/c_cpp'
      when 'Ruby'
        'ace/mode/ruby'
      when 'Python'
        'ace/mode/python'
      when 'Java'
        'ace/mode/java'
      when 'Rust'
        'ace/mode/rust'
      when 'Go'
        'ace/mode/golang'
      else
        'ace/mode/c_cpp'
    end
  end

  # render a key pair as two lines (label & value)
  # input can be either label & value or object & field
  def key_pair(label: nil, value: nil, obj: nil, field: nil, width: 4, as: nil, className: '')
    label = field.capitalize if label.nil? && obj && field && obj.respond_to?(field)
    value = obj.send(field).to_s if value.nil? && obj && field && obj.respond_to?(field)

    # convert value
    if as&.to_sym == :yes_no
      if value&.downcase == 'true'
        value = "<span class='badge text-bg-success'>Yes</span>"
      else
        value = "<span class='badge text-bg-danger'>No</span>"
      end
    end

    #render
    content = <<~HTML
      <div class="col-md-#{width} mb-3 #{className}"><div class="fw-bold">#{label}</div>#{value}</div>
    HTML
    return content.html_safe
  end

  def user_title_bar(user)
    header = ''
    time_left = ''

    #
    # if the contest is over
    if GraderConfiguration.time_limit_mode?
      if user.contest_finished?
        header = <<CONTEST_OVER
<tr><td colspan="2" align="center">
<span class="contest-over-msg">THE CONTEST IS OVER</span>
</td></tr>
CONTEST_OVER
      end
      if !user.contest_started?
        time_left = "&nbsp;&nbsp;" + (t 'title_bar.contest_not_started')
      else
        time_left = "&nbsp;&nbsp;" + (t 'title_bar.remaining_time') + 
          " #{format_short_duration(user.contest_time_left)}"
      end
    end
    
    #
    # if the contest is in the anaysis mode
    if GraderConfiguration.analysis_mode?
      header = <<ANALYSISMODE
<tr><td colspan="2" align="center">
<span class="contest-over-msg">ANALYSIS MODE</span>
</td></tr>
ANALYSISMODE
    end

    contest_name = GraderConfiguration['contest.name']

    #
    # build real title bar
    result = <<TITLEBAR
<div class="title">
<table>
#{header}
<tr>
<td class="left-col">
<br/>
</td>
<td class="right-col">#{contest_name}</td>
</tr>
</table>
</div>
TITLEBAR
    result.html_safe
  end

  def markdown(text)
    markdown = RDiscount.new(text)
    markdown.to_html.html_safe
  end


  BOOTSTRAP_FLASH_MSG = {
    success: 'alert-success',
    error: 'alert-danger',
    alert: 'alert-danger',
    notice: 'alert-info'
  }

  def bootstrap_class_for(flash_type)
    BOOTSTRAP_FLASH_MSG.fetch(flash_type.to_sym, flash_type.to_s)
  end

  def active_class_when(options = {},cname = @active_controller, aname = @active_action)
    class_name = ' active '
    ok = true
    options.each do |k,v|
      ok = false if k == :controller && v.to_s != cname
      ok = false if k == :action && v.to_s != aname
    end
    return class_name if ok && options.size > 0
    return ''
  end

  def is_admin
    @current_user && @current_user.admin?
  end


end

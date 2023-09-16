sub_count_by_date = Hash.new(0)
json.draw params['draw']&.to_i
#json.recordsTotal @recordsTotal
#json.recordsFiltered @recordsFiltered
json.data do
  json.array! @submissions do |sub|
    sub_count_by_date[sub.submitted_at.to_date] += 1
    json.extract! sub, :grader_comment, :ip_address, :id, :submitted_at, :points, :full_name, :login, :pretty_name, :user_id, :user_full_name
    json.extract! sub, :problem_id, :name
    #json.id "<a href='#{submission_path(sub)}'>#{sub.id}</a>"
    #json.submitted_at sub.submitted_at.strftime('%Y-%m-%d %H:%M')
    #json.points "#{sub.points}/#{sub.problem&.full_score}"
    #json.problem do
    #  json.long_name sub.problem ? sub.problem.long_name : '-- deleted problem --'
    #end
    #json.user do
    #  json.login sub.user ? "<a href='#{stat_user_path(sub.user)}'>(#{sub.user&.login})</a> #{sub.user&.full_name}" : '-- deleted user --'
    #end
    #json.language do
    #  json.pretty_name sub.language&.pretty_name
    #end
  end
end
json.sub_count_by_date sub_count_by_date

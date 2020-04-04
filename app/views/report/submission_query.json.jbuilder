json.draw params['draw']&.to_i
json.recordsTotal @recordsTotal
json.recordsFiltered @recordsFiltered
json.data do
  json.array! @submissions do |sub|
    json.extract! sub, :id, :points, :grader_comment, :ip_address
    json.submitted_at sub.submitted_at.to_s(:db)
    json.problem do
      json.long_name sub.problem&.long_name
    end
    json.user do
      json.login sub.user&.login
    end
    json.language do
      json.pretty_name sub.language&.pretty_name
    end
  end
end

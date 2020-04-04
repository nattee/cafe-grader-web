json.draw params['draw']&.to_i
json.recordsTotal @recordsTotal
json.recordsFiltered @recordsFiltered
json.data do
  json.array! @submissions do |sub|
    json.extact! sub, :id, :points, :grader_comment
    json.submitted_at sub.submitted_at
    json.problem do
      json.long_name sub.problem&.long_name
    end
    json.user do
      json.login sub.user&.login
    end
  end
end

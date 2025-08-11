json.draw params['draw']&.to_i
json.recordsTotal @recordsTotal
json.recordsFiltered @recordsFiltered
json.data do
  json.array! @jobs do |job|
    json.extract! job, :id, :queue_name, :class_name, :status ,:created_at
  end
end

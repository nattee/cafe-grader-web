# for data table
json.data do
  json.array! @problems do |prob|
    json.extract! prob, :id, :name, :full_name, :difficulty, :permitted_lang, :date_added
    json.extract! prob, :available, :view_testcase
    json.tags prob.tags.pluck(:name)
  end
end

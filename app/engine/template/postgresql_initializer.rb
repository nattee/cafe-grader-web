# we expect the first argument to be a hash of all options
dataset = JSON.parse(ARGV[1],symbolize_names: true)
config = YAML.load_file('postgresql_initializer.yml',symbolize_names: true)

workspace_path = Pathname.new(ARGV[2])

# import sql into the database
db = config[:database_name]
user = config[:database_user]
pass = config[:database_password]

dataset[:testcases].each do |testcase_id,v|

  testcase_input = Pathname.new(v[:file])
  translated_input = Pathname.new(workspace_path) + (testcase_input.base.to_s + '.' + testcase_id)

  #read sql dump
  sql_command = File.read(testcase_input)

  #translate table name
  dataset[:table_name_translation].each do |from|
    sql_command.gsub!(from,from + '_' + k.to_s)
  end

  #write new sql dump
  File.write(translated_input,sql_command)

  cmd = "/usr/bin/psql postgresql://#{user}:#{pass}@localhost/#{db} -f #{translated_input}"
end



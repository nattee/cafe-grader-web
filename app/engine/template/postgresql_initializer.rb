#!/usr/bin/env ruby
# we expect the second argument to be a hash of all options
require 'json'
require 'yaml'

puts '------------------'
puts 'arg 1 = ' + ARGV[0];
puts 'arg 2 = ' + ARGV[1];
puts 'arg 3 = ' + ARGV[2];

dataset = JSON.parse(ARGV[0],symbolize_names: true)
config = YAML.load_file(ARGV[1],symbolize_names: true)
workspace_path = Pathname.new(ARGV[2])


# import sql into the database
db = config[:database_name]
user = config[:database_user]
pass = config[:database_password]

dataset[:testcases].each do |testcase_id,v|

  testcase_input = Pathname.new(v[:inp_file])
  translated_input = Pathname.new(workspace_path) + (testcase_input.basename.to_s + '.' + testcase_id.to_s)

  #read sql dump
  sql_command = File.read(testcase_input)

  #translate table name
  config[:table_name_translation].each do |from|
    sql_command.gsub!(from,from + '_' + testcase_id.to_s)
  end

  #write new sql dump
  File.write(translated_input,sql_command)

  cmd = "/usr/bin/psql postgresql://#{user}:#{pass}@localhost/#{db} -f #{translated_input}"
  system(cmd)
end

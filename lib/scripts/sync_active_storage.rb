remote_rails_root = 'cafe_grader/web'
remote_host = '10.0.5.50'

remote_base = "#{remote_host}:#{remote_rails_root}/storage"

query = ActiveStorage::Attachment.where.not(name: 'compiled_files').includes(:blob)

count = query.count

query.each.with_index do |att,idx|
  key = att.blob.key
  src = [remote_base,key[0..1],key[2..3],key].join '/'
  dst = Rails.root.join 'storage',key[0..1],key[2..3],key
  dst.dirname.mkpath
  cmd = "scp #{src} #{dst}"
  if dst.exist? && dst.size == att.blob.byte_size
    puts "#{idx + 1}/#{count} already downloaded"
  else
    puts "#{idx + 1}/#{count} #{cmd}"
    `#{cmd}`
  end
end

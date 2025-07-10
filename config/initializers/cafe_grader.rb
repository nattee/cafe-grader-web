Rails.configuration.worker = Rails.application.config_for(:worker)
Rails.configuration.llm = Rails.application.config_for(:llm)

# build llm service key into provider
# provider[x] is the service object class name that provides llm model x
# We can get the actual class by  Rails.configuration.llm[:provider]["gemini-2.5-pro"].constantize
provider = Hash.new
Rails.configuration.llm.each do |x|
  # skip when the config is malformed
  next unless x.count >= 2
  next unless x[1].is_a? String

  class_name = x[0]
  x[1].split(',').each { |model| provider[model] = 'Llm::'+class_name.to_s }
end
Rails.configuration.llm[:provider] = provider

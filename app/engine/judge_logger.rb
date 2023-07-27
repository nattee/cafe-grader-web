class JudgeLogger
  def self.logger
    @@logger ||= Logger.new(Rails.root.join 'log','judge.log')
    return @@logger
  end

end

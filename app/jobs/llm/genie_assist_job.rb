module Llm
  class GenieAssistJob < SubmissionAssistJob
    queue_as :default

    private

    def service_class
      Llm::GenieAssist
    end
  end
end

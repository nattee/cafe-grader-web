module Llm
  class GenieAssistJob < CommentAssistJob
    queue_as :default

    private

    def service_class
      Llm::GenieAssist
    end
  end
end

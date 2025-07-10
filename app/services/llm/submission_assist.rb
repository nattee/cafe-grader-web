module Llm
  class SubmissionAssist
    attr_reader :submission, :problem, :error

    # convenience method, this simply init and then call the service from the class
    # This now accepts any set of keyword arguments (`**args`) and passes
    # them directly to the `new` method. This is the key change.
    def self.call(**args)
      new(**args).call
    end

    def initialize(submission:, **args)
      @submission = submission
      @problem = submission.problem
      @error = nil
      @other_args = args

      # Create a placeholder comment
      @record = @other_args[:comment]
    end

    def call
      # This is the "template method"
      data = prepare_data
      response = execute_call(data)
      handle_response(response)
    rescue Faraday::Error => e
      @error = "API Communication Error: #{e.message}"
      handle_error
      nil
    end

    private

    # Centralized connection method
    def self.connection(api_base_url)
      Faraday.new(url: api_base_url) do |f|
        # Set the total time to allow for the request.
        f.options.timeout = 300 # 5 minutes

        # Set the time to wait for the initial connection to be opened.
        # This can usually be short.
        f.options.open_timeout = 10 # 10 seconds

        # Set the time to wait for a chunk of the response to be read.
        # This is the most important one for slow, generative APIs.
        f.options.read_timeout = 300 # 5 minutes

        f.request :json
        f.response :raise_error
        f.adapter Faraday.default_adapter
      end
    end

    # To be implemented by subclasses
    def prepare_data
      raise NotImplementedError, "#{self.class} must implement #prepare_data"
    end

    def execute_call(data)
      raise NotImplementedError, "#{self.class} must implement #execute_call"
    end

    # for parsing the response into a additional data
    # This must return a hash that will be merged with @record
    # and save to the comments of the submission
    #
    # May use @parsed_body
    def parse_response
      raise NotImplementedError, "#{self.class} must implement #parse_specific_data"
    end

    # Can be a common implementation or overridden
    def handle_response(response)
      @record.cost = 10
      @record.llm_response = response.body

      # prepare the @parsed_body for the parse_response of the subclasses
      @parsed_body = JSON.parse(response.body)
      @record.update(parse_response)
    end

    def handle_error
      @record.merge!({cost: 0, body: @error})
      @response.body += "* #{@error}\n* Request finished at #{Time.zone.now}"
      @response.save
    end

    def provider_name
      raise NotImplementedError, "#{self.class} must implement #provider_name"
    end
  end
end

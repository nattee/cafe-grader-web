module Llm
  class GenieAssist < SubmissionAssist
    PERMITTED_MODEL = ["gemini-2.5-pro", "gemini-2.5-flash", "Claude-3.5-Sonnet", "Claude-3.5-Haiku"]

    private

    # required implementation from SubmissionAssist
    def provider_name
      'Chula Genie'
    end

    # required implementation from SubmissionAssist
    def prepare_data
      @model = @other_args[:model] || PERMITTED_MODEL.first
      @model = PERMITTED_MODEL.first unless PERMITTED_MODEL.include? @model
      {
        model: @model,
        messages: build_messages,
        stream: false
      }.to_json
    end

    # required implementation from SubmissionAssist
    def execute_call(data)
      token = Llm::TokenManager.fetch_chula_genie_token

      unless token
        @error = "Could not obtain authentication token for ChulaGenie. Aborting."
        handle_error
        return nil
      end

      # the API credentials for chula genie
      genie = Rails.application.credentials.llm.genie

      # call
      conn = SubmissionAssist.connection(genie[:host])
      conn.post(genie[:completion_path]) do |req|
        req.headers['Authorization'] = "Bearer #{token}"
        req.body = data
      end
    end

    # required implementation from SubmissionAssist
    def parse_response
      {
        body: @parsed_body['choices'][0]['message']['content'],
        llm_model: @model,
        remark: "#{@model} (via #{provider_name})",
        title: "Assistance by #{@model}"
      }
    end


    # --- Helper Methods for Data Preparation ---

    # call API to get a list of models
    def self.list_model
      token = Llm::TokenManager.fetch_chula_genie_token
      unless token
        puts "Could not obtain authentication token for ChulaGenie. Aborting."
        return nil
      end

      # the API credentials for chula genie
      genie = Rails.application.credentials.llm.genie

      # call
      conn = connection(genie[:host])
      response = conn.get(genie[:model_path]) do |req|
        req.headers['Authorization'] = "Bearer #{token}"
      end

      if response.success?
        # Parse the JSON response body
        models = JSON.parse(response.body)
        puts "Successfully fetched models:"
        # Pretty print the JSON
        puts JSON.pretty_generate(models)
        return models
      else
        # Handle errors
        puts "Error fetching models."
        puts "Status: #{response.status}"
        puts "Body: #{response.body}"
        return nil
      end
    end

    def build_messages
      [
        {
          role: "system",
          content: build_system_content_array
        },
        {
          role: "user",
          content: [
            {
              type: "text",
              text: "The verdict of the source code is:\n\n```\n#{@submission.grader_comment}\n```"
            },
            {
              type: "text",
              text: "Here is my code:\n\n```\n#{@submission.source}\n```"
            },
            build_pdf_attachment
          ]
        }
      ]
    end

    def build_system_content_array
      # following text are the example prompt
      # the actual prompt is retrieved from the llm tags via

      prompt_array = get_prompts_from_problem_tags
      result = prompt_array.map { |prompt| {type: 'text', text: prompt} }
      raise RuntimeError.new("There is no LLM Prompt for the problem") if result.blank?
      return result
    end

    # Main logic to encode the attached problem statement PDF into a Base64 object.
    def build_pdf_attachment
      # 1. Ensure the problem has a statement attached.
      return nil unless problem.statement.attached?

      # 2. (Optional but Recommended) Validate that the attachment is a PDF.
      return nil unless problem.statement.content_type == 'application/pdf'

      # 3. Read the raw PDF binary content directly from Active Storage.
      pdf_binary = problem.statement.download

      # 4. Base64 encode the PDF binary. `strict_encode64` avoids newlines in the output.
      encoded_pdf = Base64.strict_encode64(pdf_binary)

      # 5. Construct the final data URI string.
      data_uri = "data:application/pdf;base64,#{encoded_pdf}"

      # 6. Return the hash object in the format the API expects.
      {
        type: "image_url", # API spec uses 'image_url' for this type of content
        image_url: data_uri
      }
    rescue => e
      # Log the error if the attachment process fails for any reason.
      msg = "Failed to build PDF attachment for Problem ##{problem.id}: #{e.message}"
      Rails.logger.error msg
      raise RuntimeError.new(msg)
      nil
    end
  end
end

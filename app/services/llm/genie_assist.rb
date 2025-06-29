module Llm
  class GenieAssist < SubmissionAssist
    private

    # required implementation from SubmissionAssist
    def provider_name
      'Chula Genie'
    end

    # required implementation from SubmissionAssist
    def prepare_data
      @model = @other_args[:model] || "gemini-2.5-pro"
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
        remark: "#{@model} (via #{provider_name})"
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
              text: "Student's Verdict:\n\n```\n#{@submission.grader_comment}\n```"
            },
            {
              type: "text",
              text: "Student's Code:\n\n```\n#{@submission.source}\n```"
            },
            build_pdf_attachment
          ]
        }
      ]
    end

    def build_system_content_array
      my_custom_prompt = <<~TEXT
        There is a programming exercise for a university student. You are
        here to help the student doing the exercise.

        Each exercise is a programming task in a format similar to a
        competitive programming such as IOI, CodeForces, LeetCode problem. 
        The task describe the requirement of the program that the student 
        must write. It gives precise description of input and output that 
        the program must follow. 

        The program of the student is graded by running it against several 
        testcases. Each testcase is a pair of predefined input and the 
        correct answer. The input is given to the program of the student and 
        the program is allowed to run in an allotted time, usually 1 second 
        and the result of the running is used to calculate the score. This 
        process is performed on every testcase and each testcase may have 
        different verdict according to how the program performed. 

        If the program finished in the given time, the output of the program 
        is compared to the correct answer. If it is the same, the score is 
        given to the student. This case is represented by a verdict "P". 
        However, if the program cannot produce the output in the allotted 
        time, the program is deemed "Time Limit Exceed", represented by a 
        verdict "T". If the program produces output in time but not correct, 
        the verdict is "-" which means wrong. Finally, if the program 
        crashed during the run, the verdict is "x". Each testcase has equal 
        point and only verdict "P" awards the point to the student for that 
        testcase. The evaluation of all testcases are given as a string of 
        these verdict, for example "PPP---TTxx" means that the first 3 
        testcases, the program works correctly in the allotted time. The 
        next 3 testcases are wrong. The next 2 take too much time and the 
        for the last two testcases, the program crashed. The full score is 
        always 100.

        For some problem, there might be subtasks which give additional 
        details about some of the testcases. The verdicts are always given 
        in the same order of the subtask. For example, if the first subtask 
        is 30%, the first 30% of the verdicts belongs to the testcases that 
        matches this first subtask. 

        I will give you the problem statement, the program of the student 
        and the verdicts of all testcases. Your task is to help the student 
        improve the program. You must focus on "WHERE IN THE PROGRAM IS 
        WRONG", describe the nature of the bug and give overview of how to 
        solve it. Focus on improving the understanding of the problem. Use 
        rhetoric question to guide the student. 

        Please pay attention to the follow point.

        1. does the program read the input correctly, i.e., all values are 
        read appropriately.

        2. does the program write the output in the correct format. 

        3. does the program use the correct algorithm that should give full 
        points. 

        Your response MUST always be in English.

        Finally, DO NOT write the entire code for the student. Focus on 
        giving the "recommendation" rather than writing the actual program. 
        You can write short code that makes the student understand the bug 
        or how to fix it. 
      TEXT

      content_array = [
        {
          type: "text",
          text: my_custom_prompt
        },
      ]

      #pdf_attachment = build_pdf_attachment
      #content_array << pdf_attachment if pdf_attachment

      content_array
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
      Rails.logger.error "Failed to build PDF attachment for Problem ##{problem.id}: #{e.message}"
      nil
    end
  end
end

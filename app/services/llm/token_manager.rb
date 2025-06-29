
module Llm
  class TokenManager
    # Define a unique key for this token in the Rails cache.
    CACHE_KEY = "llm_api:chula:bearer_token".freeze

    # The token is valid for 4 hours. We'll cache it for 3 hours and 55 minutes
    # to create a 5-minute buffer. This prevents a race condition where we
    # retrieve a token just seconds before it expires.
    CACHE_EXPIRES_IN = 3.hours + 50.minutes

    # The public method to get the token.
    def self.fetch_chula_genie_token
      # Rails.cache.fetch is perfect for this.
      # It attempts to read the value from the cache. If the key is not found
      # or has expired, it executes the block, saves the return value to the
      # cache under the given key, and then returns that value.
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_EXPIRES_IN) do
        Rails.logger.info "LLM token cache miss. Fetching new token from API."
        get_new_chula_genie_token_from_api
      end
    rescue => e
      # Log detailed error information from Faraday
      error_details = e.response ? "Status: #{e.response[:status]}, Body: #{e.response[:body]}" : e.message
      Rails.logger.error "Failed to fetch Genie API token: #{error_details}"
      nil
    end

    private

    # This method contains the actual API call logic.
    # It's only executed when the cache is empty.
    def self.get_new_chula_genie_token_from_api
      genie = Rails.application.credentials.llm.genie

      # Set up the connection with the base URL
      conn = Faraday.new(url: genie[:host]) do |f|
        f.request :json         # Automatically encodes the request body as JSON
        f.response :raise_error # Raise Faraday::Error on 4xx/5xx responses
        f.adapter Faraday.default_adapter
      end

      response = conn.post(genie[:token_path]) do |req|
        # Set the required headers
        req.headers['Content-Type'] = 'application/json'
        req.headers['api-key'] = genie[:api_key]

        # Set the request body
        req.body = {
          app_id: genie[:app_id],
          email: genie[:client_email],
          cunet_id: genie[:client_id]
        }
      end

      # Parse the response and extract the token from the "token" key.
      JSON.parse(response.body).fetch("token")
    end
  end
end

require "rails_helper"

# Blanket-gate sweep over EVERY /api/v1 route.
#
# The routes are enumerated from the routing table at test time, so an
# endpoint added later is covered automatically: if its controller skips
# authenticate_api_user! (or the single-user lockdown gate inside it), this
# spec fails without anyone having to remember to write a test for it.
# Motivated by the 2026-08-19 incident where the web UI was locked down via
# single_user_mode but the API kept accepting student submissions.
RSpec.describe "API authorization sweep", type: :request do
  fixtures :users, :roles, :grader_configurations, :sites,
           :problems, :datasets, :testcases,
           :groups, :groups_users, :groups_problems,
           :contests, :contests_users, :contests_problems,
           :submissions, :languages, :evaluations

  # [verb, concrete_path] for every /api/v1 route, with dummy values in place
  # of path params. The blanket gates run in before_actions, so requests are
  # rejected before any param is looked at — nonexistent ids are fine.
  # auth/login is the one deliberate exception (it must work without a token;
  # its own gates are covered in authorization_spec.rb).
  def api_routes
    Rails.application.routes.routes.filter_map do |route|
      spec = route.path.spec.to_s
      next unless spec.start_with?("/api/v1")
      next if spec.include?("auth/login")
      verb = route.verb.downcase
      next if verb.blank?
      [verb, spec.sub("(.:format)", "").gsub(/:[a-z_]+/, "999999")]
    end
  end

  it "enumerates the API surface (guard against the sweep going blind)" do
    expect(api_routes.length).to be >= 30
  end

  it "rejects every endpoint without a token" do
    api_routes.each do |verb, path|
      send(verb, path)
      expect(response).to have_http_status(:unauthorized),
        "#{verb.upcase} #{path}: expected 401 without a token, got #{response.status}"
      expect(JSON.parse(response.body)["error"]).to eq("Missing authorization token"),
        "#{verb.upcase} #{path}: 401 did not come from the token gate"
    end
  end

  it "rejects every endpoint for a non-admin while single-user mode is on" do
    set_grader_config("system.single_user_mode", "true")
    headers = auth_header_for(users(:john))
    api_routes.each do |verb, path|
      send(verb, path, headers: headers)
      expect(response).to have_http_status(:forbidden),
        "#{verb.upcase} #{path}: expected 403 in single-user mode, got #{response.status}"
      expect(JSON.parse(response.body)["error"]).to match(/single-user/i),
        "#{verb.upcase} #{path}: 403 did not come from the single-user gate"
    end
  end

  it "does not lock admins out while single-user mode is on" do
    set_grader_config("system.single_user_mode", "true")
    headers = auth_header_for(users(:admin))
    api_routes.each do |verb, path|
      send(verb, path, headers: headers)
      next unless response.status == 403
      expect(JSON.parse(response.body)["error"]).not_to match(/single-user/i),
        "#{verb.upcase} #{path}: admin was blocked by the single-user gate"
    end
  end
end

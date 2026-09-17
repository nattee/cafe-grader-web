require "test_helper"

class MainControllerTest < ActionDispatch::IntegrationTest
  test "unauthenticated user is redirected to login" do
    get list_main_path
    assert_redirected_to login_main_path
  end

  test "authenticated user can see list page" do
    sign_in_as("john", "hello")
    get list_main_path
    assert_response :success
  end

  test "login page loads successfully" do
    get root_path
    assert_response :success
  end

  test "logout redirects to root" do
    sign_in_as("john", "hello")
    get logout_main_path
    assert_response :redirect
  end

  test "admin can see list page" do
    sign_in_as("admin", "admin")
    get list_main_path
    assert_response :success
  end

  test "submit creates submission via editor" do
    sign_in_as("admin", "admin")
    prob = problems(:prob_add)
    lang = languages(:Language_c)
    assert_difference "Submission.count" do
      post submit_main_path, params: {
        submission: { problem_id: prob.id },
        language_id: lang.id,
        editor_text: "int main() { return 0; }"
      }
    end
  end

  # Regression: the file-picker JS reads the chosen file into the Ace editor
  # as text (editor_controller.js#loadFileToEditor -> readAsText), so a zip
  # upload arrives with a non-blank `editor_text`. Before 2026-09-17 the
  # controller let editor_text win and stored the mangled zip in `source`
  # (live_edit.dig), so the Digital CLI got garbage as its circuit and
  # reported "Exited with error status 200". An archive by name must always be
  # captured raw into `binary`.
  test "submit stores a zip upload as binary even when the editor is populated" do
    lang = Language.create!(name: "digital", pretty_name: "Digital", ext: "dig")
    sign_in_as("admin", "admin")
    prob = problems(:prob_add)
    zip_path = Rails.root.join("lib", "language", "digital", "Demo.zip")
    upload = Rack::Test::UploadedFile.new(zip_path, "application/zip")

    sub = nil
    assert_difference "Submission.count" do
      post submit_main_path, params: {
        submission: { problem_id: prob.id },
        language_id: lang.id,
        editor_text: "PK\u0003\u0004 mojibake the zip looked like in the editor",
        file: upload
      }
      sub = Submission.order(:id).last
    end

    assert_equal lang.id, sub.language_id
    assert sub.submitted_archive?, "zip must be captured as binary, not editor_text"
    assert_nil sub.source
    assert_equal "Demo.zip", sub.source_filename
    assert_equal File.binread(zip_path), sub.binary
  end

  test "help page loads" do
    sign_in_as("john", "hello")
    get help_main_path
    assert_response :success
  end

  # --- Dead actions (no routes) ---
  #
  # MainController defines `source`, `load_output`, `confirm_contest_start`,
  # and `error` actions, but none are routed in config/routes.rb. The
  # singular `resource :main` block only routes login/logout/list/help/submit
  # /submission/prob_grop. These actions are therefore unreachable; either
  # add routes or remove the actions.

  test "main#source is not routed (DEAD action)" do
    assert_raises(ActionController::UrlGenerationError) do
      url_for(controller: "main", action: "source", only_path: true)
    end
  end

  test "main#load_output is not routed (DEAD action)" do
    assert_raises(ActionController::UrlGenerationError) do
      url_for(controller: "main", action: "load_output", only_path: true)
    end
  end

  test "main#confirm_contest_start is not routed (DEAD action)" do
    assert_raises(ActionController::UrlGenerationError) do
      url_for(controller: "main", action: "confirm_contest_start", only_path: true)
    end
  end

  # Regression: a logged-in user whose session points at an enabled contest
  # they are NOT enrolled in has a nil contest-membership; the header countdown
  # read extra_time_second off it and 500'd every page (2 hits, 2026-09-09).
  test "list does not 500 when the session contest excludes the user" do
    set_grader_config("system.mode", "contest")
    contest = contests(:contest_a)
    membership = ContestUser.find_by(contest: contest, user: users(:james))  # james_in_contest_a
    sign_in_as("james", "morning")
    get set_active_contest_path(contest)                # sets session[:contest_id] while james is a member
    membership.destroy                                  # now the session points at a contest he is not in
    get list_main_path
    assert_response :success
  ensure
    set_grader_config("system.mode", "standard")
  end
end

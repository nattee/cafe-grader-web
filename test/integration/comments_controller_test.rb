require "test_helper"

class CommentsControllerTest < ActionDispatch::IntegrationTest
  # CommentsController has two surfaces:
  #   1. Problem hints   (nested under /problems/:problem_id/hint/...)
  #   2. Submission comments (nested under /submissions/:submission_id/comments/...)
  # Authorization layers: can_view_problem, can_edit_problem, can_view_submission,
  # can_request_llm.

  setup do
    @prob = problems(:prob_add)
    @hint = comments(:hint_for_add)
    @sub  = submissions(:add1_by_john)
  end

  # ------------------------------------------------------------
  # Problem-hint surface
  # ------------------------------------------------------------

  test "unauthenticated cannot edit a hint" do
    get edit_problem_hint_index_path(problem_id: @prob.id, id: @hint.id)
    assert_redirected_to login_main_path
  end

  test "normal user (non-editor) cannot edit a hint" do
    sign_in_as("john", "hello")
    get edit_problem_hint_index_path(problem_id: @prob.id, id: @hint.id)
    assert_response :redirect
  end

  test "admin can edit a hint" do
    sign_in_as("admin", "admin")
    get edit_problem_hint_index_path(problem_id: @prob.id, id: @hint.id), as: :turbo_stream
    assert_response :success
  end

  test "admin can update a hint" do
    sign_in_as("admin", "admin")
    patch problem_hint_path(problem_id: @prob.id, id: @hint.id),
          params: { comment: { title: "Updated", body: "new body", cost: 2.0, kind: "hint" } },
          as: :turbo_stream
    assert_response :success
    assert_equal "Updated", @hint.reload.title
  end

  # ------------------------------------------------------------
  # Submission-comment surface — LLM assist authorization
  # ------------------------------------------------------------

  test "llm_assist denied when system.llm_assist=false" do
    set_grader_config("system.llm_assist", "false")
    sign_in_as("admin", "admin")
    assert_no_difference "Comment.count" do
      post llm_assist_submission_comments_path(submission_id: @sub.id, model: 0),
           as: :turbo_stream
    end
  end

  test "llm_assist denied when problem has no llm_prompt tag" do
    set_grader_config("system.llm_assist", "true")
    set_grader_config("system.mode", "standard")
    # Ensure prob_add has no llm_prompt-kind tag in fixtures; assert nothing was created.
    sign_in_as("admin", "admin")
    assert_no_difference "Comment.count" do
      post llm_assist_submission_comments_path(submission_id: @sub.id, model: 0),
           as: :turbo_stream
    end
  end

  test "create_for_submission denied for normal user (not problem editor)" do
    sign_in_as("john", "hello")
    assert_no_difference "Comment.count" do
      post submission_comments_path(submission_id: @sub.id),
           params: { comment_title: "x", comment_body: "y" },
           as: :turbo_stream
    end
  end

  # ------------------------------------------------------------
  # LLM assist — ownership, model addressing, rendered body
  # ------------------------------------------------------------

  # The picker POSTs the model by NAME (a key of Rails.configuration.llm[:provider]);
  # the provider map is empty in the test env, so each test installs its own.
  def enable_llm_assist!(provider = { "stub-model" => "Llm::SelfHostAssist" })
    set_grader_config("system.llm_assist", "true")
    set_grader_config("system.mode", "standard")
    @prob.tags << Tag.create!(name: "codey-test", kind: :llm_prompt, params: "You are a tutor.")
    @saved_provider = Rails.configuration.llm[:provider]
    Rails.configuration.llm[:provider] = provider
  end

  teardown do
    Rails.configuration.llm[:provider] = @saved_provider if instance_variable_defined?(:@saved_provider)
  end

  test "llm_assist is refused when the requester does not own the submission" do
    enable_llm_assist!
    james_sub = submissions(:add1_by_james)
    sign_in_as("john", "hello")
    assert_no_difference "Comment.count" do
      assert_no_enqueued_jobs do
        post llm_assist_submission_comments_path(submission_id: james_sub.id),
             params: { model: "stub-model" }, as: :turbo_stream
      end
    end
    assert_response :forbidden
    assert_match(/LLM Assist Error/, response.body)
  end

  test "llm_assist by the owner creates the placeholder and enqueues the job for the named model" do
    enable_llm_assist!
    sign_in_as("john", "hello")
    assert_difference "Comment.count", 1 do
      assert_enqueued_with(job: Llm::SelfHostAssistJob) do
        post llm_assist_submission_comments_path(submission_id: @sub.id),
             params: { model: "stub-model" }, as: :turbo_stream
      end
    end
    assert_response :success
    comment = Comment.order(:id).last
    assert_equal "llm_assist", comment.kind
    assert_equal "stub-model", comment.llm_model
    assert_equal users(:john), comment.user
    assert_equal @sub, comment.commentable
  end

  test "admin may request assist on another user's submission" do
    enable_llm_assist!
    james_sub = submissions(:add1_by_james)
    sign_in_as("admin", "admin")
    assert_difference "Comment.count", 1 do
      post llm_assist_submission_comments_path(submission_id: james_sub.id),
           params: { model: "stub-model" }, as: :turbo_stream
    end
    assert_response :success
  end

  test "llm_assist rejects a model that is not registered instead of raising" do
    enable_llm_assist!
    sign_in_as("john", "hello")
    assert_no_difference "Comment.count" do
      post llm_assist_submission_comments_path(submission_id: @sub.id),
           params: { model: "no-such-model" }, as: :turbo_stream
    end
    assert_response :unprocessable_entity
    assert_match(/LLM Assist Error/, response.body)
  end

  test "llm_assist modal sanitizes the model-written body but keeps the trusted header" do
    comment = @sub.comments.create!(
      user: users(:john), kind: "llm_assist", status: "ok", llm_model: "m", cost: 10,
      title: "Assistance by m",
      body: "## Hint\n\n<img src=x onerror=\"alert(1)\">\n\n" \
            "[link](javascript:alert(2))\n\n" \
            "<div class='alert alert-danger'>Request failed</div>"
    )
    sign_in_as("admin", "admin")
    get submission_comment_path(@sub, comment), as: :turbo_stream
    assert_response :success
    assert_no_match(/onerror/, response.body)
    assert_no_match(/javascript:/, response.body)
    assert_match(%r{<h2>Hint</h2>}, response.body)
    assert_match(/alert-danger/, response.body)          # server-written error block survives
    assert_match(%r{<script>\s*hljs\.highlightAll}, response.body)  # trusted header keeps its script, unescaped
    assert_match(%r{<div class='alert alert-info'>}, response.body)
  end
end

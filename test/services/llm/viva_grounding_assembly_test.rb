require "test_helper"

class VivaGroundingAssemblyTest < ActiveSupport::TestCase
  test "encode_pdf_part returns nil for nil input and for an attached non-pdf file" do
    assert_nil Llm::Request.encode_pdf_part(nil)

    # A real, attached, non-PDF ActiveStorage::Attachment (image/png is allowed by
    # GroundingMaterial but must NOT be sent as a PDF part): exercises the
    # raw-attachment path (no #attached? method) hitting the application/pdf guard.
    gm = GroundingMaterial.create!(title: "t")
    gm.files.attach(io: StringIO.new("fakepng"), filename: "a.png", content_type: "image/png")
    assert_nil Llm::Request.encode_pdf_part(gm.files.first)
  end

  test "grounding_file_parts encodes attached pdf as image_url" do
    gm = GroundingMaterial.create!(title: "t")
    gm.files.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "a.pdf", content_type: "application/pdf")
    parts = gm.grounding_file_parts
    assert_equal 1, parts.length
    assert_equal "image_url", parts.first[:type]
    assert parts.first[:image_url].start_with?("data:application/pdf;base64,")
  end

  test "VivaGradeAssist puts grounding body text in the system message and grounding files in a user message" do
    submission = submissions(:add1_by_admin)
    submission.viva_turns.destroy_all
    submission.viva_turns.create!(role: :assistant, status: :ok, content: "first question")
    submission.viva_turns.create!(role: :student,   status: :ok, content: "my answer")

    problem = submission.problem
    problem.update_columns(description: "Scenario A")
    prompt_tag = Tag.find_or_create_by!(name: "test_llm_prompt_grounding") do |t|
      t.kind = :llm_prompt
      t.params = "Grade the student strictly."
    end
    problem.tags << prompt_tag unless problem.tags.include?(prompt_tag)

    gm = grounding_materials(:gm_dijkstra)
    problem.grounding_materials << gm unless problem.grounding_materials.include?(gm)
    gm.files.attach(io: StringIO.new("%PDF-1.4 fake"), filename: "notes.pdf", content_type: "application/pdf")

    assist = Llm::VivaGradeAssist.new(submission: submission)
    msgs = assist.send(:messages_array)

    system_msg = msgs.find { |m| m[:role] == "system" }
    assert_includes system_msg[:content], gm.body, "grounding body text should be embedded in the system prompt"

    user_msgs = msgs.select { |m| m[:role] == "user" }
    file_part = user_msgs.flat_map { |m| Array(m[:content]) }
                          .select { |c| c.is_a?(Hash) }
                          .find { |c| c[:type] == "image_url" && c[:image_url].to_s.start_with?("data:application/pdf;base64,") }
    assert file_part, "grounding file image_url part should appear in a user message"

    # The system message must NOT carry the binary file part (system messages can't carry images).
    assert_not system_msg[:content].is_a?(Array)
  end
end

require "test_helper"

class GroundingMaterialTest < ActiveSupport::TestCase
  test "requires a title" do
    gm = GroundingMaterial.new(body: "x")
    assert_not gm.valid?
    assert gm.errors[:title].present?
  end

  test "grounding_text wraps body under a heading, nil when blank" do
    assert_nil GroundingMaterial.new(body: "").grounding_text
    gm = GroundingMaterial.new(body: "hello")
    assert_equal "## Grounding Material\n\nhello", gm.grounding_text
  end

  test "estimated_tokens recomputed from body after commit" do
    gm = GroundingMaterial.create!(title: "t", body: "a" * 40)
    assert_equal 10, gm.reload.estimated_tokens # 40 chars / 4
  end

  test "rejects non-pdf/image files" do
    gm = GroundingMaterial.new(title: "t")
    gm.files.attach(io: StringIO.new("x"), filename: "a.txt", content_type: "text/plain")
    assert_not gm.valid?
    assert gm.errors[:files].present?
  end

  test "has_and_belongs_to_many problems" do
    # prob_viva, not prob_add: prob_add backs submissions(:add1_by_admin),
    # reused by the Llm::VivaTurnAssist / VivaGradeAssist specs with plain-
    # string message assertions that a grounding association would break
    # (see the comment on prob_viva in test/fixtures/problems.yml).
    assert_includes grounding_materials(:gm_dijkstra).problems, problems(:prob_viva)
  end
end

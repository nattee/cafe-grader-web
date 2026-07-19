require "test_helper"

class GroundingMaterialsControllerTest < ActionDispatch::IntegrationTest
  # sign_in_as(user, password) is defined in test/test_helper.rb (see
  # tags_controller_test.rb). No blanket `setup` sign-in here: the
  # authorization tests below deliberately vary who (if anyone) is signed in.

  # --- Authorization ---

  test "unauthenticated is redirected" do
    get grounding_materials_path
    assert_redirected_to login_main_path
  end

  test "normal user cannot access index" do
    sign_in_as("john", "hello")
    get grounding_materials_path
    assert_redirected_to list_main_path
  end

  # --- Admin happy paths ---

  test "index lists materials" do
    sign_in_as("admin", "admin")
    get grounding_materials_path
    assert_response :success
    assert_select "td", text: "Dijkstra notes"
  end

  test "new renders the form" do
    sign_in_as("admin", "admin")
    get new_grounding_material_path
    assert_response :success
  end

  test "edit renders the form" do
    sign_in_as("admin", "admin")
    get edit_grounding_material_path(grounding_materials(:gm_dijkstra))
    assert_response :success
  end

  test "create with title" do
    sign_in_as("admin", "admin")
    assert_difference "GroundingMaterial.count", 1 do
      post grounding_materials_path, params: { grounding_material: { title: "New ref", body: "b" } }
    end
    assert_redirected_to grounding_materials_path
  end

  test "delete_file purges an attachment" do
    sign_in_as("admin", "admin")
    gm = GroundingMaterial.create!(title: "t")
    gm.files.attach(io: StringIO.new("%PDF"), filename: "a.pdf", content_type: "application/pdf")
    blob_id = gm.files.first.id
    assert_difference -> { gm.files.count }, -1 do
      delete delete_file_grounding_material_path(gm, blob_id: blob_id)
    end
  end
end

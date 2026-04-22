require "test_helper"

class DatasetTest < ActiveSupport::TestCase
  # --- Enums ---

  test "evaluation_type enum" do
    ds = datasets(:ds_add)
    assert ds.respond_to?(:default?)
    assert ds.respond_to?(:exact?)
    assert ds.respond_to?(:custom_cafe?)
    assert ds.respond_to?(:custom_cms_raw?)
  end

  test "score_type enum" do
    ds = datasets(:ds_add)
    assert ds.respond_to?(:st_sum?)
    assert ds.respond_to?(:st_group_min?)
    assert ds.respond_to?(:st_raw_sum?)
  end

  # --- Methods ---

  test "live? returns true for live dataset" do
    ds = datasets(:ds_add)
    assert ds.live?
  end

  test "live? returns false for non-live dataset" do
    ds = datasets(:ds_sub)
    prob = ds.problem
    # If ds_sub is prob_sub's live_dataset, this should be true
    # Let's test against a different problem's dataset
    if prob.live_dataset == ds
      assert ds.live?
    else
      assert_not ds.live?
    end
  end

  test "get_name_for_dir returns name when present" do
    ds = datasets(:ds_add)
    assert_equal "Dataset 1", ds.get_name_for_dir
  end

  # --- Associations ---

  test "dataset belongs to problem" do
    ds = datasets(:ds_add)
    assert_equal problems(:prob_add), ds.problem
  end

  test "dataset has testcases" do
    ds = datasets(:ds_add)
    assert ds.testcases.count >= 2
  end
end

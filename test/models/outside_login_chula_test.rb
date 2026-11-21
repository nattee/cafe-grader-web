require 'test_helper'

# chula_cp only: CU-net (CUCAS) behind master's OutsideLogin seam.
class OutsideLoginChulaTest < ActiveSupport::TestCase
  test "CU-net is chula_cp's outside login" do
    assert_equal 'CU-net', User.outside_login_name
  end

  test "the site switch drives outside_login_on?" do
    GraderConfiguration.where(key: 'chula.allow_cu_net_password').delete_all
    GraderConfiguration.create!(key: 'chula.allow_cu_net_password', value_type: 'boolean', value: 'true')
    reset_grader_config_cache
    assert User.outside_login_on?
    GraderConfiguration.where(key: 'chula.allow_cu_net_password').update_all(value: 'false')
    reset_grader_config_cache
    assert_not User.outside_login_on?
  end

  test "outside_password? asks CUCAS" do
    u = users(:john)
    u.stub(:authenticated_by_cucas?, ->(pw) { pw == 'cu-pass' }) do
      assert User.outside_password?(u, 'cu-pass')
      assert_not User.outside_password?(u, 'other')
    end
  end
end

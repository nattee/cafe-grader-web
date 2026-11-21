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

  test "a string-typed 'true' switch row reads ON and 'false' reads OFF" do
    GraderConfiguration.where(key: 'chula.allow_cu_net_password').delete_all
    GraderConfiguration.create!(key: 'chula.allow_cu_net_password', value_type: 'string', value: 'true')
    reset_grader_config_cache
    assert User.outside_login_on?
    GraderConfiguration.where(key: 'chula.allow_cu_net_password').update_all(value: 'false')
    reset_grader_config_cache
    assert_not User.outside_login_on?
  end

  def switch_on!
    GraderConfiguration.where(key: 'chula.allow_cu_net_password').delete_all
    GraderConfiguration.create!(key: 'chula.allow_cu_net_password', value_type: 'boolean', value: 'true')
    reset_grader_config_cache
  end

  test "login_result end to end: a blocked student with the CU-net password is refused" do
    switch_on!
    contests(:contest_a).update!(outside_login_off: true)
    u = users(:james)
    User.stub(:find_by_login, u) do
      u.stub(:authenticated_by_cucas?, true) do
        r = User.login_result('james', 'cu-pass')
        assert_nil r.user
        assert_equal :slip_password_required, r.refusal
      end
    end
    assert u.reload.authenticated?('morning')
  end

  test "login_result end to end: an unblocked user logs in and the CU-net password becomes local" do
    switch_on!
    u = users(:john)
    User.stub(:find_by_login, u) do
      u.stub(:authenticated_by_cucas?, true) do
        r = User.login_result('john', 'cu-pass')
        assert_equal u, r.user
      end
    end
    assert u.reload.authenticated?('cu-pass')
  end
end

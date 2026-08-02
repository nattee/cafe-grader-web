require 'test_helper'

# Regression guard for the argv-order bug: CMS invokes its checker as
# (input, correct, USER) (cms/grading/steps/trusted.py), while cafe's
# original custom_cms evaluator follows the legacy testlib/Codeforces
# order (input, USER, correct). cms_comparator exists specifically to
# match CMS's own order for tasks imported from CMS, without disturbing
# custom_cms for existing cafe problems that depend on its order.
#
# Checker#check_command only needs the ivars JudgeBase#initialize sets
# (@worker_id, @box_id) plus @prob_checker_file, which is normally filled
# in by prepare_dataset_directory (itself driven by a live Dataset +
# on-disk judge paths). Poking @prob_checker_file directly via
# instance_variable_set is the smallest honest seam here: check_command
# is a pure string-builder over ivars/params, and standing up a full
# Dataset/Testcase/Submission fixture chain plus isolate/judge directories
# just to exercise argv-order string formatting would be testing the
# fixtures, not the bug.
class CheckerCommandTest < ActiveSupport::TestCase
  setup do
    @checker = Checker.new('test-worker', 'test-box')
    @checker.instance_variable_set(:@prob_checker_file, 'CHECKER')
  end

  test 'cms_comparator orders argv as input, correct, user (CMS-native)' do
    cmd = @checker.check_command('cms_comparator', 'INPUT', 'OUTPUT', 'ANS')
    assert_equal 'CHECKER INPUT ANS OUTPUT', cmd
  end

  test 'custom_cms keeps its legacy argv order: input, user, correct' do
    cmd = @checker.check_command('custom_cms', 'INPUT', 'OUTPUT', 'ANS')
    assert_equal 'CHECKER INPUT OUTPUT ANS', cmd
  end
end

require 'test_helper'

# JudgeBase#isolate_options_by_lang is the per-language extra argv for
# isolate, applied to both the compile and the run sandbox (compiler.rb,
# evaluator.rb). Checker is the lightest class that mixes JudgeBase in.
class IsolateOptionsTest < ActiveSupport::TestCase
  setup { @judge = Checker.new('test-worker', 'test-box') }

  test "go raises the open-file limit above isolate's default of 64 (issue #40)" do
    opts = @judge.isolate_options_by_lang('go')
    assert_match(/--open-files=(\d+)/, opts)
    assert_operator opts[/--open-files=(\d+)/, 1].to_i, :>=, 512
    assert_includes opts, '--env=GOCACHE=/gocache'
  end

  test 'an unknown language gets no extra options' do
    assert_equal '', @judge.isolate_options_by_lang('brainfuck')
  end
end

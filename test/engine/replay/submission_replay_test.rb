require "test_helper"
require "tmpdir"
require "minitest/mock"

class Replay::SubmissionReplayTest < ActiveSupport::TestCase
  # A tiny real problem: import the fibo_minimal example, attach one model
  # solution, grade it once so it has a stored grade, then replay.
  # NOTE: this test actually grades via the judge engine. If grading is
  # unavailable in this env it will be skipped with a clear message (the
  # unit pieces — sampler/diff — are covered by their own tests).
  test "replay of a losslessly round-tripped problem reports zero mismatches and cleans up" do
    # Opt-in: needs a running dev server at :3000 + isolate (grade_sync uses HTTP).
    # The unit pieces (sampler/diff) are covered by their own tests; the real
    # end-to-end exercise is Task 17's capstone run.
    skip "set REPLAY_LIVE=1 with a dev server + judge to run this" unless ENV["REPLAY_LIVE"] == "1"

    pi = ProblemImporter.new
    pi.import_dataset_from_dir(Rails.root.join("test", "problem_examples", "fibo").to_s,
                              "rc_src_#{SecureRandom.hex(3)}", user: users(:admin))
    problem = pi.problem
    # give it one graded submission (a correct C++ solution ships in the fixture)
    sol = File.read(Dir[Rails.root.join("test", "problem_examples", "fibo", "model_solutions", "**", "*.cpp")].first)
    seed = Submission.new(user: users(:admin), problem: problem, language: languages(:Language_cpp),
                          source_filename: "sol.cpp", submitted_at: Time.zone.now)
    seed.source = sol
    seed.save!(validate: false)
    Replay::ReplayGrader.grade_sync(seed, problem.live_dataset)
    seed.reload
    skip "seed did not grade (env)" if seed.points.nil?

    before = Problem.count
    report = Replay::SubmissionReplay.run(problem, limit: 10)

    assert_equal 0, report[:mismatch], "expected no non-benign mismatches: #{report[:mismatch_details].inspect}"
    assert report[:replayed] >= 1
    assert_equal before, Problem.count, "throwaway _rc_ problem must be destroyed"
    assert_empty Problem.where("name LIKE ?", "#{Replay::SubmissionReplay::RC_PREFIX}%")
  end

  test "run destroys the clone and cleans up jobs even when grading raises" do
    pi = ProblemImporter.new
    pi.import_dataset_from_dir(Rails.root.join("test", "problem_examples", "fibo").to_s,
                              "rcsrc_#{SecureRandom.hex(3)}", user: users(:admin))
    problem = pi.problem
    seed = Submission.new(user: users(:admin), problem: problem, language: languages(:Language_cpp),
                          source_filename: "a.cpp", submitted_at: Time.zone.now)
    seed.source = "int main(){}"
    seed.save!(validate: false)
    # +1.minute, not Time.zone.now: submissions.graded_at is a bare `datetime`
    # (whole-second precision) while datasets.updated_at is `datetime(6)`
    # (microseconds). A same-second graded_at truncates down and can land
    # BEFORE the dataset's fractional updated_at, tripping ReplaySampler's
    # staleness cutoff (graded_at >= dataset.updated_at) nondeterministically
    # -- this was observed to fail ~40% of runs before the buffer was added.
    seed.update_columns(points: 100, graded_at: 1.minute.from_now)

    before_problems = Problem.count

    Replay::ReplayGrader.stub :grade_sync, ->(*) { raise "boom" } do
      report = Replay::SubmissionReplay.run(problem, limit: 5)
      assert report[:errored] >= 1, "a raised grade must be bucketed as errored, not lost"
    end

    assert_equal before_problems, Problem.count, "throwaway _rc_ clone must be destroyed"
    assert_empty Problem.where("name LIKE ?", "#{Replay::SubmissionReplay::RC_PREFIX}%")
    assert_equal 0, Submission.joins(:user).where(users: { login: "replay_bot" }).count,
                 "no replay_bot submissions may remain"
  end
end

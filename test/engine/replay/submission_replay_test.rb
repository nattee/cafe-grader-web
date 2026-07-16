require "test_helper"
require "tmpdir"

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
end

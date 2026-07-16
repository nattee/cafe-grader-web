require "test_helper"

class Replay::ReplaySamplerTest < ActiveSupport::TestCase
  # Build a problem whose live dataset was updated at a known time, plus
  # submissions in each score bucket, some graded before that time (stale).
  def build(dataset_updated_at:)
    problem = Problem.create!(name: "smp_#{SecureRandom.hex(3)}", full_name: "Sampler")
    ds = Dataset.create!(problem: problem, name: "D1")
    problem.update!(live_dataset: ds)
    ds.update_column(:updated_at, dataset_updated_at)
    problem
  end

  def add_sub(problem, points:, graded_at:)
    s = Submission.new(user: users(:admin), problem: problem, language: languages(:Language_cpp),
                       source_filename: "a.cpp", submitted_at: graded_at, points: points)
    s.source = "int main(){}"
    s.save!(validate: false)
    s.update_columns(points: points, graded_at: graded_at)
    s
  end

  test "stratifies across buckets and skips stale submissions" do
    cutoff = Time.zone.parse("2026-01-01 00:00")
    p = build(dataset_updated_at: cutoff)
    # fresh (graded after cutoff)
    add_sub(p, points: 0,   graded_at: cutoff + 1.day)
    add_sub(p, points: 50,  graded_at: cutoff + 1.day)
    add_sub(p, points: 100, graded_at: cutoff + 1.day)
    # stale (graded before cutoff) — must be skipped
    add_sub(p, points: 100, graded_at: cutoff - 1.day)

    out = Replay::ReplaySampler.sample(p, limit: 100)
    assert_equal 1, out[:skipped_stale]
    assert_equal 3, out[:submissions].size
    assert_equal({ zero: 1, partial: 1, full: 1 }, out[:buckets])
  end

  test "limit is respected via round-robin across buckets" do
    cutoff = Time.zone.parse("2026-01-01 00:00")
    p = build(dataset_updated_at: cutoff)
    6.times { add_sub(p, points: 0,   graded_at: cutoff + 1.day) }
    6.times { add_sub(p, points: 100, graded_at: cutoff + 1.day) }
    out = Replay::ReplaySampler.sample(p, limit: 4)
    assert_equal 4, out[:submissions].size
    pts = out[:submissions].map { |s| s.points.to_f }
    # round-robin should pull from both buckets, not 4 from one
    assert pts.count(0.0).between?(1, 3), "expected a mix of buckets, got #{pts.inspect}"
  end
end

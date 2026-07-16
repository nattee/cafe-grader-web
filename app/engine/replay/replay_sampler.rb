module Replay
  module ReplaySampler
    module_function

    # Up to `limit` of the problem's graded submissions, stratified across
    # zero / partial / full score buckets. Skips submissions graded before the
    # live dataset's updated_at (their stored grade predates the dataset we clone).
    def sample(problem, limit: 100)
      ds = problem.live_dataset
      cutoff = ds&.updated_at
      graded = problem.submissions.where.not(points: nil).order(:id).to_a
      fresh, stale = graded.partition do |s|
        cutoff.nil? || s.graded_at.nil? || s.graded_at >= cutoff
      end

      max_pts = fresh.map { |s| s.points.to_f }.max || 0.0
      buckets = { zero: [], partial: [], full: [] }
      fresh.each do |s|
        pts = s.points.to_f
        key = if pts <= 0 then :zero
              elsif max_pts.positive? && pts >= max_pts then :full
              else :partial
              end
        buckets[key] << s
      end

      picked = round_robin(buckets.values, limit)
      { submissions: picked, skipped_stale: stale.size,
        buckets: buckets.transform_values(&:size) }
    end

    # Interleave lists so `limit` picks are spread across non-empty buckets.
    def round_robin(lists, limit)
      lists = lists.map(&:dup)
      result = []
      i = 0
      while result.size < limit && lists.any?(&:any?)
        list = lists[i % lists.size]
        result << list.shift if list.any?
        i += 1
      end
      result
    end
  end
end

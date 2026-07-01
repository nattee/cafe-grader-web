module ReportHelper
  # Render a comma-separated list of course names, capped at `cap`. When there
  # are more, append a "+N more" link that opens the given offcanvas drawer, so
  # the cap is visible (and the full list is one click away). `names` is an
  # array of strings.
  def report_capped_names(names, drawer_id:, cap: 3)
    return content_tag(:span, "none", class: "fst-italic") if names.blank?

    shown     = names.first(cap)
    remainder = names.size - shown.size
    pieces    = [content_tag(:span, shown.join(", "))]

    if remainder.positive?
      pieces << link_to("+#{remainder} more", "##{drawer_id}",
                        class: "fw-semibold text-decoration-none",
                        data: { bs_toggle: "offcanvas", bs_target: "##{drawer_id}" })
    end

    safe_join(pieces, " ")
  end
end

module ProblemsHelper
  def render_tag(ptag)
    return "<span class='badge text-bg-secondary bg-opacity-100'>#{ptag.name}</span>".html_safe
  end

  def render_star(count)
    count ||= 0
    #icons = (['star'] * (count/2)) + ['star_half'] * (count%2)
    #html = icons.map{ |x| "<i class='mi mi-bs md-18'>#{x}</i>"}.join
    html = ""
    html += "<i class=\"mi mi-bs md-18\" style=\"font-variation-settings: 'FILL' 1\">star</i>" * (count/2) if count >= 2
    html += "<i class=\"mi mi-bs md-18\" > star_half </i>" if count % 2 == 1
    return "<span style='display: inline-block;'>#{html}</span>".html_safe
  end
end

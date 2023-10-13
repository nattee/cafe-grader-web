module ProblemsHelper
  def render_tag(ptag)
    return "<span class='badge text-bg-secondary bg-opacity-100'>#{ptag.name}</span>".html_safe
  end

  def render_star(count)
    count ||= 0
    icons = (['star'] * (count/2)) + ['star_half'] * (count%2)
    html = icons.map{ |x| "<i class='mi mi-bs md-18'>#{x}</i>"}.join
    return "<span style='display: inline-block;'>#{html}</span>".html_safe
  end
end

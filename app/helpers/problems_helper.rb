module ProblemsHelper
  def render_tag(ptag)
    return "<span class='badge text-bg-secondary bg-opacity-100'>#{ptag.name}</span>".html_safe
  end
end

module MainHelper

  def link_to_description_if_any(name, problem, **options)
    if !problem.url.blank?
      return link_to name, problem.url, **options
    elsif problem.statement.attached?
      return link_to name, get_statement_problem_path(problem), target: '_blank', data: {turbo: false}, **options
    else
      return ''
    end
  end

end

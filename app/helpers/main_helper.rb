module MainHelper

  def link_to_description_if_any(name, problem)
    if !problem.url.blank?
      return link_to name, problem.url
    elsif problem.statement.attached?
      return link_to name, get_statement_problem_path(problem, problem.statement&.filename), target: '_blank', data: {turbo: false}
    else
      return ''
    end
  end

end

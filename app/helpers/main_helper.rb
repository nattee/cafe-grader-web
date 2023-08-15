module MainHelper

  def link_to_description_if_any(name, problem)
    if !problem.url.blank?
      return link_to name, problem.url
    elsif problem.statement.attached?
      return link_to name, get_statement_problem_path(problem), target: '_blank'
    elsif !problem.description_filename.blank?
      basename, ext = problem.description_filename.split('.')
      return link_to name, download_task_path(problem.id,basename,ext), target: '_blank'
    else
      return ''
    end
  end

end

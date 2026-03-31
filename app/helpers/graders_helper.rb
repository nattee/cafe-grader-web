module GradersHelper
  def job_type_text(job_type)
    return 'all' if job_type.blank? || job_type == 'compile evaluate score'
    return job_type
  end

  def job_type_badges(job_type)
    return ['all'] if job_type.blank? || job_type.strip == 'compile evaluate score'
    job_type.split
  end
end

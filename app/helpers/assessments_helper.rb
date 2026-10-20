module AssessmentsHelper
  def status_class(status)
    "status-#{AssessmentStatus.normalize(status) || 'unmapped'}"
  end

  def score_label(score)
    case score.state
    when :scored then "#{score.value} / 100"
    when :incomplete then "Not yet scored"
    else "Score unavailable"
    end
  end

  def company_date(timestamp)
    timestamp.in_time_zone(current_user.company.timezone).strftime("%d %b %Y")
  end
end

require "csv"

class AssessmentsCsv
  HEADERS = %w[employee created_date status score].freeze

  def initialize(timezone:)
    @timezone = timezone
  end

  def write_header(stream)
    stream.write(CSV.generate_line(HEADERS))
  end

  def write_row(stream, assessment, employee_name:)
    score = AssessmentScore.call(assessment.responses_json)
    score_value = case score.state
    when :scored then score.value
    when :incomplete then "Not yet scored"
    else "Score unavailable"
    end
    stream.write(CSV.generate_line([
      spreadsheet_text(employee_name || "Employee Name unavailable"),
      assessment.created_at.in_time_zone(@timezone).to_date.iso8601,
      AssessmentStatus.normalize(assessment.status) || "unmapped",
      score_value
    ]))
  end

  private

  def spreadsheet_text(value)
    text = value.to_s
    text.match?(/\A(?:[ \t\r\n]*[=+@-]|[\t\r\n])/) ? "'#{text}" : text
  end
end

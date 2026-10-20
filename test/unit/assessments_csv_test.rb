require "minitest/autorun"
require "stringio"
require "date"
require_relative "../../app/models/assessment_status"
require_relative "../../app/services/assessment_score"
require_relative "../../app/services/assessments_csv"

class AssessmentsCsvTest < Minitest::Test
  # Zone conversion is covered by Rails date tests; this isolates the CSV contract.
  Timestamp = Struct.new(:date) do
    def in_time_zone(_zone)
      self
    end
    def to_date
      date
    end
  end
  Row = Struct.new(:created_at, :status, :employee_email, :responses_json)

  def test_all_dashboard_columns_without_raw_answers_or_email
    output = StringIO.new
    serializer = AssessmentsCsv.new(timezone: "London")
    serializer.write_header(output)
    answers = AssessmentScore::KEYS.zip([2, 1, 3, 0, 2]).to_h.merge("comments" => "PRIVATE_NOTE")
    row = Row.new(Timestamp.new(Date.new(2026, 10, 17)), "DONE", "PRIVATE_EMAIL", answers)
    serializer.write_row(output, row, employee_name: "Alex Morgan")
    assert_equal "employee,created_date,status,score\nAlex Morgan,2026-10-17,completed,40\n", output.string
    refute_includes output.string, "PRIVATE"
  end

  def test_arbitrary_status_and_employee_cannot_inject_a_formula
    output = StringIO.new
    row = Row.new(Timestamp.new(Date.new(2026, 10, 17)), '=HYPERLINK("evil")')
    AssessmentsCsv.new(timezone: "London").write_row(output, row, employee_name: "=1+1")
    assert_equal ["'=1+1", "2026-10-17", "unmapped", "Not yet scored"], CSV.parse_line(output.string)
  end

  def test_real_zero_missing_and_invalid_scores
    [ [AssessmentScore::KEYS.to_h { |key| [key, 0] }, "0"],
      [nil, "Not yet scored"], [{ "chair_support" => 5 }, "Score unavailable"] ].each do |answers, expected|
      output = StringIO.new
      row = Row.new(Timestamp.new(Date.new(2026, 10, 17)), "pending", nil, answers)
      AssessmentsCsv.new(timezone: "London").write_row(output, row, employee_name: nil)
      assert_equal "Employee unavailable", CSV.parse_line(output.string)[0]
      assert_equal expected, CSV.parse_line(output.string)[3]
    end
  end

  def test_names_are_csv_escaped
    output = StringIO.new
    row = Row.new(Timestamp.new(Date.new(2026, 10, 17)), "pending")
    name = 'Morgan, Alex "AJ"'
    AssessmentsCsv.new(timezone: "London").write_row(output, row, employee_name: name)
    assert_equal name, CSV.parse_line(output.string)[0]
  end
end

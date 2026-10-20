require "minitest/autorun"
require_relative "../../app/models/assessment_status"

class AssessmentStatusTest < Minitest::Test
  def test_aliases_and_whitespace
    ["complete", "comp", "done", " COMPLETED\t", "\nDone\r"].each do |value|
      assert_equal "completed", AssessmentStatus.normalize(value)
    end
  end

  def test_unknowns_are_not_assumed_pending
    [nil, "", "n/a", "mystery", 0, []].each { |value| assert_nil AssessmentStatus.normalize(value) }
    assert_equal "Unmapped", AssessmentStatus.label("=SUM(1,2)")
  end

  def test_filter_variants_share_the_mapping
    assert_equal %w[completed complete comp done], AssessmentStatus.variants("completed")
    AssessmentStatus::VALUES.each { |value| assert_equal value, AssessmentStatus.normalize(value) }
  end
end

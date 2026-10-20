require "minitest/autorun"
require_relative "../../db/demo_assessments"
require_relative "../../app/services/assessment_score"
require_relative "../../app/models/assessment_status"

class DemoAssessmentsUnitTest < Minitest::Test
  def history(slug, employee_index)
    DemoAssessments.history(slug: slug, employee_index: employee_index, latest_at: Time.utc(2026, 10, 20, 10))
  end

  def test_every_employee_has_four_distinguishable_visits
    DemoAssessments::PROFILES.each_key do |slug|
      8.times do |employee_index|
        rows = history(slug, employee_index)
        assert_equal 4, rows.length
        assert_equal 4, rows.map { |row| row[:created_at] }.uniq.length
        assert_equal 4, rows.map { |row| row[:responses_json] }.uniq.length
        assert_equal 4, rows.map { |row| AssessmentStatus.normalize(row[:status]) }.uniq.length
        scores = rows.map { |row| AssessmentScore.call(row[:responses_json]) }
        assert_equal 4, scores.map { |score| [score.state, score.value] }.uniq.length
        assert_equal rows.map { |row| row[:created_at] }.sort.reverse, rows.map { |row| row[:created_at] }
      end
    end
  end

  def test_documented_examples_have_different_scores_at_each_visit
    assert_equal [40, 65, 90, 10], history("northstar", 0).map { |row| AssessmentScore.call(row[:responses_json]).value }
    assert_equal [20, 40, 65, 90], history("fieldwork", 0).map { |row| AssessmentScore.call(row[:responses_json]).value }
    assert_equal 0, AssessmentScore.call(history("northstar", 1).first[:responses_json]).value
    assert_equal 100, AssessmentScore.call(history("northstar", 2).first[:responses_json]).value
  end

  def test_data_is_deterministic_and_only_latest_visit_has_missing_or_invalid_answers
    DemoAssessments::PROFILES.each_key do |slug|
      [3, 4].each do |employee_index|
        rows = history(slug, employee_index)
        assert_equal rows, history(slug, employee_index)
        assert_equal(employee_index == 3 ? :incomplete : :invalid, AssessmentScore.call(rows.first[:responses_json]).state)
        assert rows.drop(1).all? { |row| AssessmentScore.call(row[:responses_json]).state == :scored }
      end
    end
  end
end

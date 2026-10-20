# Also runnable without Rails: ruby test/unit/assessment_score_test.rb
require "minitest/autorun"
require_relative "../../app/services/assessment_score"

class AssessmentScoreTest < Minitest::Test
  def answers(values)
    AssessmentScore::KEYS.zip(values).to_h
  end

  def test_known_scores_and_real_zero
    { [0, 0, 0, 0, 0] => 0, [4, 4, 4, 4, 4] => 100, [2, 2, 2, 2, 2] => 50,
      [2, 1, 3, 0, 2] => 40, [1, 0, 0, 0, 0] => 5 }.each do |input, expected|
      result = AssessmentScore.call(answers(input))
      assert_equal :scored, result.state
      assert_equal expected, result.value
      assert_nil result.reason
    end
  end

  def test_missing_is_not_zero
    [nil, {}, answers([0, 1, 2, 3, nil])].each do |input|
      result = AssessmentScore.call(input)
      assert_equal :incomplete, result.state
      assert_nil result.value
    end
  end

  def test_strict_types_and_ranges
    [-1, 5, "2", 2.0, true, false, "", [], {}].each do |bad|
      result = AssessmentScore.call(answers([bad, 0, 0, 0, 0]))
      assert_equal :invalid, result.state
      assert_nil result.value
    end
  end

  def test_malformed_structure
    [[], "{}", 0, false].each { |input| assert_equal :invalid, AssessmentScore.call(input).state }
  end

  def test_invalid_takes_precedence_over_missing
    assert_equal :invalid, AssessmentScore.call(answers(["2", nil, 0, 0, 0])).state
  end

  def test_ignores_extra_fields_without_mutating_input
    input = answers([2, 1, 3, 0, 2]).merge("comments" => "PRIVATE", "score" => 99).freeze
    assert_equal 40, AssessmentScore.call(input).value
    assert_equal 99, input["score"]
    assert AssessmentScore.call(input).frozen?
  end
end

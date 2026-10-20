class AssessmentScore
  KEYS = %w[chair_support screen_position keyboard_mouse desk_space movement_breaks].freeze
  Result = Struct.new(:state, :value, :reason, keyword_init: true)

  def self.call(responses)
    return result(:incomplete, nil, :missing_answers) if responses.nil?
    return result(:invalid, nil, :invalid_structure) unless responses.is_a?(Hash)

    answers = KEYS.map { |key| responses[key] }
    if answers.any? { |answer| !answer.nil? && !(answer.is_a?(Integer) && (0..4).cover?(answer)) }
      return result(:invalid, nil, :invalid_answers)
    end
    return result(:incomplete, nil, :missing_answers) if answers.any?(&:nil?)

    result(:scored, answers.sum * 5, nil)
  end

  def self.result(state, value, reason)
    Result.new(state: state, value: value, reason: reason).freeze
  end
  private_class_method :result
end

class AssessmentStatus
  VALUES = %w[pending in_progress completed needs_follow_up archived].freeze
  ALIASES = { "complete" => "completed", "comp" => "completed", "done" => "completed" }.freeze

  def self.normalize(value)
    return nil unless value.is_a?(String)
    key = value.strip.downcase
    VALUES.include?(key) ? key : ALIASES[key]
  end

  def self.variants(value)
    [value] + ALIASES.select { |_key, canonical| canonical == value }.keys
  end

  def self.label(value)
    normalized = normalize(value)
    normalized ? normalized.tr("_", " ").capitalize : "Unmapped"
  end
end

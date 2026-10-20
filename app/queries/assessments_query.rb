class AssessmentsQuery
  # Same ASCII whitespace semantics as Ruby String#strip for status compatibility.
  NORMALIZED_STATUS_SQL = "lower(btrim(assessments.status, E' \\t\\n\\r\\f\\013'))".freeze

  def initialize(scope:, filters:)
    raise ArgumentError, "Invalid assessment filters" unless filters.valid?
    @scope, @filters = scope, filters
  end

  def call
    relation = @scope
    relation = relation.where("assessments.created_at >= ?", @filters.start_at) if @filters.from
    relation = relation.where("assessments.created_at < ?", @filters.end_before) if @filters.to
    if @filters.status
      relation = relation.where("#{NORMALIZED_STATUS_SQL} IN (?)", AssessmentStatus.variants(@filters.status))
    end
    relation
  end
end

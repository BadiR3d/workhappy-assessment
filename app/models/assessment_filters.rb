require "date"

class AssessmentFilters
  attr_reader :from, :to, :status, :errors, :today

  def initialize(params, timezone:, today: timezone.today)
    @timezone = timezone
    @today = today
    @errors = []
    @from = parse_date(params["from"], "Start date")
    @to = parse_date(params["to"], "End date")
    raw_status = params["status"]
    @status = raw_status if raw_status.is_a?(String) && !raw_status.empty?
    if !raw_status.nil? && raw_status != "" && !AssessmentStatus::VALUES.include?(raw_status)
      @errors << "Choose an approved status."
    end
    @errors << "End date must be on or after start date." if from && to && from > to
    @errors.freeze
    freeze
  end

  def valid?
    errors.empty?
  end

  def start_at
    midnight(from) if from
  end

  def end_before
    midnight(to + 1) if to
  end

  def to_h
    { from: from&.iso8601, to: to&.iso8601, status: status }.compact
  end

  private

  def midnight(date)
    @timezone.local(date.year, date.month, date.day).utc
  end

  def parse_date(value, label)
    return nil if value.nil? || value == ""
    unless value.is_a?(String) && value.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      @errors << "#{label} must be a valid YYYY-MM-DD date."
      return nil
    end
    date = Date.iso8601(value)
    raise ArgumentError if date < Date.new(1900, 1, 1)
    @errors << "#{label} cannot be in the future." if date > today
    date
  rescue ArgumentError
    @errors << "#{label} must be a valid date on or after 1900-01-01."
    nil
  end
end

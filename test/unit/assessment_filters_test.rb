require "minitest/autorun"
require_relative "../../app/models/assessment_status"
require_relative "../../app/models/assessment_filters"

class AssessmentFiltersUnitTest < Minitest::Test
  UTCZone = Struct.new(:unused) do
    def local(year, month, day)
      Time.utc(year, month, day)
    end
  end

  def filters(values)
    AssessmentFilters.new(values, timezone: UTCZone.new, today: Date.new(2026, 10, 20))
  end

  def test_valid_range_is_half_open
    value = filters("from" => "2026-10-01", "to" => "2026-10-17", "status" => "completed")
    assert value.valid?
    assert_equal Time.utc(2026, 10, 1), value.start_at
    assert_equal Time.utc(2026, 10, 18), value.end_before
  end

  def test_invalid_dates_ranges_and_types
    [{ "from" => "2026-02-30" }, { "from" => "17/10/2026" }, { "from" => [] },
     { "from" => "2026-10-18", "to" => "2026-10-17" }, { "to" => "0000-01-01" },
     { "status" => "done" }, { "status" => [] }, { "status" => "anything" }].each do |input|
      refute filters(input).valid?, input.inspect
    end
  end

  def test_empty_filters
    value = filters("from" => "", "to" => "", "status" => "")
    assert value.valid?
    assert_nil value.start_at
    assert_nil value.end_before
    assert_equal({}, value.to_h)
  end

  def test_today_is_allowed_and_future_dates_are_rejected
    assert filters("from" => "2026-10-20", "to" => "2026-10-20").valid?
    ["from", "to"].each do |field|
      result = filters(field => "2026-10-21")
      refute result.valid?
      assert result.errors.any? { |error| error.include?("cannot be in the future") }
    end
  end

end

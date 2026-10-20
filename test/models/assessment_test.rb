require "test_helper"

class AssessmentTest < ActiveSupport::TestCase
  setup { @company, @user, @employee = create_workspace }

  test "normalizes known statuses on all ordinary saves" do
    record = create_assessment(@company, @employee, status: " DONE ")
    assert_equal "completed", record.status
    record.update_columns(status: "comp")
    record.update!(employee_email: "updated@example.invalid")
    assert_equal "completed", record.reload.status
  end

  test "does not silently assign unknowns" do
    [nil, "", "n/a", "unexpected"].each do |value|
      record = Assessment.new(company: @company, employee: @employee, status: value)
      refute record.valid?
      assert record.errors[:status].any?
    end
  end

  test "prevents mismatched employee company" do
    other_company, _user, other_employee = create_workspace("Other")
    record = Assessment.new(company: @company, employee: other_employee, status: "pending")
    refute record.valid?
    assert record.errors[:employee].any?
    assert_not_equal @company.id, other_company.id
  end

  test "database prevents employee company mismatch even when validation is bypassed" do
    _other_company, _user, other_employee = create_workspace("Other")
    record = create_assessment(@company, @employee)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      Assessment.transaction(requires_new: true) { record.update_columns(employee_id: other_employee.id) }
    end
  end

  test "London date ranges honor daylight saving changes" do
    filters = AssessmentFilters.new({ "from" => "2026-03-29", "to" => "2026-03-29" }, timezone: ActiveSupport::TimeZone["London"], today: Date.new(2026, 11, 1))
    assert_equal 23.hours, filters.end_before - filters.start_at
    filters = AssessmentFilters.new({ "from" => "2026-10-25", "to" => "2026-10-25" }, timezone: ActiveSupport::TimeZone["London"], today: Date.new(2026, 11, 1))
    assert_equal 25.hours, filters.end_before - filters.start_at
  end

  test "NOT VALID check leaves historical rows but protects new and updated rows" do
    record = create_assessment(@company, @employee)
    record.update_columns(status: nil)
    connection = ActiveRecord::Base.connection
    connection.add_check_constraint :assessments,
      "status IS NOT NULL AND status IN ('pending','in_progress','completed','needs_follow_up','archived')",
      name: "test_status_allowed", validate: false
    assert_nil record.reload.status
    assert_raises(ActiveRecord::StatementInvalid) do
      Assessment.transaction(requires_new: true) { record.update_columns(employee_email: "changed@example.invalid") }
    end
    record.update!(status: "done")
    assert_equal "completed", record.reload.status
  ensure
    connection&.remove_check_constraint :assessments, name: "test_status_allowed", if_exists: true
  end
end

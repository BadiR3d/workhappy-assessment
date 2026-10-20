require "test_helper"
require "csv"

class AssessmentsTest < ActionDispatch::IntegrationTest
  setup do
    Rails.cache.clear
    @company, @admin, @employee = create_workspace("Northstar")
    @other_company, @other_admin, @other_employee = create_workspace("Fieldwork")
    @assessment = create_assessment(@company, @employee, created_at: Time.utc(2026, 10, 15, 12))
    @other = create_assessment(@other_company, @other_employee, created_at: Time.utc(2026, 10, 10, 12))
  end

  test "requires login for dashboard and export" do
    get assessments_path
    assert_redirected_to login_path
    get export_assessments_path
    assert_redirected_to login_path
  end

  test "dashboard exposes only the authenticated company" do
    sign_in(@admin)
    get assessments_path
    assert_response :success
    assert_includes response.body, @employee.email
    refute_includes response.body, @other_employee.email
    assert_select ".score-number", text: "50 / 100"
  end

  test "company identifiers and unsupported filters cannot widen access" do
    sign_in(@admin)
    [{ company_id: @other_company.id }, { employee_id: @other_employee.id }, { search: "anything" }].each do |filters|
      get export_assessments_path, params: filters
      assert_response :unprocessable_entity
      refute_includes response.body, @other_employee.email
    end
  end

  test "another company record cannot be read or updated" do
    sign_in(@admin)
    get assessment_path(@other)
    assert_response :not_found
    patch assessment_path(@other), params: { assessment: { status: "archived" } }
    assert_response :not_found
    assert_equal "completed", @other.reload.status
  end

  test "non-admin cannot view update or export" do
    @admin.update!(role: "member")
    sign_in(@admin)
    get assessments_path
    assert_response :forbidden
    get export_assessments_path
    assert_response :forbidden
    patch assessment_path(@assessment), params: { assessment: { status: "archived" } }
    assert_response :forbidden
  end

  test "CSV includes all dashboard columns and remains scoped" do
    @assessment.update!(responses_json: @assessment.responses_json.merge("comments" => "PRIVATE_HEALTH_MARKER"))
    sign_in(@admin)
    get export_assessments_path
    assert_response :success
    rows = CSV.parse(response.body, headers: true)
    assert_equal %w[employee created_date status score], rows.headers
    assert_equal 1, rows.length
    assert_equal "2026-10-15", rows[0]["created_date"]
    assert_equal "completed", rows[0]["status"]
    assert_equal @employee.name, rows[0]["employee"]
    assert_equal "50", rows[0]["score"]
    [@employee.email, @other_employee.name, "PRIVATE_HEALTH_MARKER", "responses_json"].each do |private_value|
      refute_includes response.body, private_value
    end
    assert_includes response.headers["Cache-Control"], "no-store"
    assert_includes response.headers["Content-Disposition"], "attachment"
  end

  test "invalid export filters fail before starting a CSV" do
    sign_in(@admin)
    [{ from: "not-a-date" }, { from: "2026-10-17", to: "2026-10-01" }, { status: "comp" }, { status: ["completed"] }].each do |filters|
      get export_assessments_path, params: filters
      assert_response :unprocessable_entity
      assert_includes response.media_type, "text/html"
      refute response.headers["Content-Disposition"]
    end
  end

  test "dashboard and export share inclusive local dates and legacy aliases" do
    @assessment.update_columns(status: " \tDONE\n") # synthetic historical fixture
    at_end = create_assessment(@company, @employee, created_at: Time.utc(2026, 10, 15, 22, 59, 59))
    create_assessment(@company, @employee, created_at: Time.utc(2026, 10, 15, 23)) # next day in London
    sign_in(@admin)
    filters = { from: "2026-10-15", to: "2026-10-15", status: "completed" }
    get assessments_path, params: filters
    assert_response :success
    assert_select "tbody tr", count: 2
    assert_select "a[href='#{assessment_path(at_end)}']", count: 1
    get export_assessments_path, params: filters
    rows = CSV.parse(response.body, headers: true)
    assert_equal 2, rows.length
    assert rows.all? { |row| row["status"] == "completed" && row["created_date"] == "2026-10-15" }
  end

  test "Apply filters form submission accepts Rails commit metadata and filters records" do
    create_assessment(@company, @employee, status: "pending", created_at: Time.utc(2026, 10, 15, 12))
    create_assessment(@company, @employee, status: "completed", created_at: Time.utc(2026, 10, 14, 12))
    sign_in(@admin)
    get assessments_path
    assert_select 'input[type="submit"][name="commit"][value="Apply filters"]'
    get assessments_path, params: { from: "2026-10-15", to: "2026-10-15", status: "completed", commit: "Apply filters" }
    assert_response :success
    assert_select "tbody tr", count: 1
    assert_select "a[href='#{assessment_path(@assessment)}']", count: 1
    assert_select 'select[name="status"] option[selected]', text: "Completed"
  end

  test "status writes normalize and do not accept mass assignment of tenant or answers" do
    sign_in(@admin)
    patch assessment_path(@assessment), params: { assessment: { status: "done", company_id: @other_company.id, responses_json: {} } }
    assert_response :see_other
    assert_equal "completed", @assessment.reload.status
    assert_equal @company.id, @assessment.company_id
    assert_equal 50, @assessment.score.value
  end

  test "unknown historical status requires an explicit valid choice" do
    @assessment.update_columns(status: "mystery")
    sign_in(@admin)
    get assessment_path(@assessment)
    assert_response :success
    assert_includes response.body, "historical status needs review"
    patch assessment_path(@assessment), params: { assessment: { status: "mystery" } }
    assert_response :unprocessable_entity
    patch assessment_path(@assessment), params: { assessment: { status: "pending" } }
    assert_response :see_other
    assert_equal "pending", @assessment.reload.status
  end

  test "empty export has headers and dashboard has an empty state" do
    sign_in(@admin)
    get assessments_path, params: { from: "1900-01-01", to: "1900-01-02" }
    assert_includes response.body, "No assessments found"
    get export_assessments_path, params: { from: "1900-01-01", to: "1900-01-02" }
    assert_equal "employee,created_date,status,score\n", response.body
  end

  test "logout removes access" do
    sign_in(@admin)
    delete logout_path
    get assessments_path
    assert_redirected_to login_path
  end

  test "date pickers cap at company today and server rejects future filters" do
    sign_in(@admin)
    today = ActiveSupport::TimeZone[@company.timezone].today
    get assessments_path
    assert_select "input[type=date][max='#{today.iso8601}']", count: 2
    get assessments_path, params: { from: (today + 1).iso8601 }
    assert_response :unprocessable_entity
    assert_includes response.body, "cannot be in the future"
    get export_assessments_path, params: { to: (today + 1).iso8601 }
    assert_response :unprocessable_entity
  end

end

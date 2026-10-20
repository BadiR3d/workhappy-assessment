require "test_helper"
require "stringio"

class LoggingTest < ActionDispatch::IntegrationTest
  test "sensitive request values and assessment payloads are absent from feature logs" do
    company, admin, employee = create_workspace
    record = create_assessment(company, employee, responses_json: { "comments" => "HEALTH_SECRET_MARKER" })
    Rails.cache.clear
    sign_in(admin)
    buffer = StringIO.new
    logger = ActiveSupport::TaggedLogging.new(Logger.new(buffer))
    original_logger = Rails.logger
    original_controller_logger = ActionController::Base.logger
    Rails.logger = logger
    ActionController::Base.logger = logger
    get export_assessments_path
    patch assessment_path(record), params: { assessment: { status: "pending", employee_email: "EMAIL_SECRET_MARKER", responses_json: { comments: "HEALTH_SECRET_MARKER" } } }
    get assessments_path, params: { search: "QUERY_SECRET_MARKER" }
    %w[HEALTH_SECRET_MARKER EMAIL_SECRET_MARKER QUERY_SECRET_MARKER].each { |marker| refute_includes buffer.string, marker }
    refute_includes buffer.string, employee.email
  ensure
    Rails.logger = original_logger if original_logger
    ActionController::Base.logger = original_controller_logger if original_controller_logger
  end
end

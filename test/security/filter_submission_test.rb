# Exercise the real filter callback without a database connection.
ENV["RAILS_ENV"] = "test"
require_relative "../../config/environment"
require "minitest/autorun"
require "action_controller/test_case"

class FilterSubmissionProbeController < AssessmentsController
  skip_before_action :require_admin

  def index
    render json: @filters.to_h
  end

  private

  def company_timezone
    ActiveSupport::TimeZone["London"]
  end
end

class FilterSubmissionTest < ActionController::TestCase
  tests FilterSubmissionProbeController

  setup do
    @routes = ActionDispatch::Routing::RouteSet.new
    @routes.draw { get "filters", to: "filter_submission_probe#index" }
  end

  test "browser submit metadata does not invalidate date and status filters" do
    get :index, params: { from: "2026-10-15", to: "2026-10-16", status: "completed", commit: "Apply filters" }
    assert_response :success
    assert_equal({ "from" => "2026-10-15", "to" => "2026-10-16", "status" => "completed" }, JSON.parse(response.body))
  end

  test "empty browser controls still allow all assessments" do
    get :index, params: { from: "", to: "", status: "", commit: "Apply filters" }
    assert_response :success
    assert_equal({}, JSON.parse(response.body))
  end
end

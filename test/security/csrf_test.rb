# Can run without PostgreSQL: bundle exec ruby test/security/csrf_test.rb
ENV["RAILS_ENV"] = "test"
require_relative "../../config/environment"
require "minitest/autorun"
require "action_dispatch/testing/integration"
require "nokogiri"

class CsrfTest < Minitest::Test
  def setup
    @previous_protection = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    @browser = ActionDispatch::Integration::Session.new(Rails.application)
    @browser.host! "localhost"
  end

  def teardown
    ActionController::Base.allow_forgery_protection = @previous_protection
  end

  def token
    @browser.get "/login"
    assert_equal 200, @browser.response.status
    assert_equal "same-origin", @browser.response.headers["Referrer-Policy"]
    Nokogiri::HTML(@browser.response.body).at_css('meta[name="csrf-token"]')["content"]
  end

  def test_same_origin_form_with_valid_token_is_accepted
    csrf_token = token
    # Logout exercises real CSRF/session middleware without a database query.
    @browser.post "/logout", params: { _method: "delete", authenticity_token: csrf_token },
      headers: { "Origin" => "http://localhost" }
    assert_equal 303, @browser.response.status
    assert_equal "http://localhost/login", @browser.response.headers["Location"]
  end

  def test_login_without_a_token_is_rejected
    @browser.get "/login"
    @browser.post "/login", params: { email: "demo@example.invalid", password: "unused" },
      headers: { "Origin" => "http://localhost" }
    assert_equal 422, @browser.response.status
  end

  def test_cross_origin_login_is_rejected_even_with_a_token
    csrf_token = token
    @browser.post "/login", params: { authenticity_token: csrf_token },
      headers: { "Origin" => "https://other.example" }
    assert_equal 422, @browser.response.status
  end
end

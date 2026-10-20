ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  self.use_transactional_tests = true

  def create_workspace(name = "Northstar")
    company = Company.create!(name: name, timezone: "London")
    user = User.create!(company: company, email: "admin@#{name.downcase}.example", password: "Demo-assessment-2026!", role: "admin")
    employee = Employee.create!(company: company, name: "#{name} Employee", email: "private@#{name.downcase}.example")
    [company, user, employee]
  end

  def create_assessment(company, employee, **attributes)
    Assessment.create!({ company: company, employee: employee, employee_email: employee.email,
      status: "completed", responses_json: AssessmentScore::KEYS.to_h { |key| [key, 2] } }.merge(attributes))
  end
end

class ActionDispatch::IntegrationTest
  def sign_in(user)
    post login_path, params: { email: user.email, password: "Demo-assessment-2026!" }
    assert_response :see_other
  end
end

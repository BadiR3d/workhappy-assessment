class Assessment < ApplicationRecord
  belongs_to :company
  belongs_to :employee
  before_validation :normalize_status
  validates :status, inclusion: { in: AssessmentStatus::VALUES, message: "must be selected from the approved statuses" }
  validate :employee_belongs_to_company

  def score
    AssessmentScore.call(responses_json)
  end

  private

  def normalize_status
    normalized = AssessmentStatus.normalize(status)
    self.status = normalized if normalized
  end

  def employee_belongs_to_company
    errors.add(:employee, "must belong to this company") if employee && employee.company_id != company_id
  end
end

class Company < ApplicationRecord
  has_many :users
  has_many :employees
  has_many :assessments
  validates :name, presence: true
  validates :timezone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }
end

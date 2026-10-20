class Employee < ApplicationRecord
  belongs_to :company
  has_many :assessments
  validates :name, :email, presence: true
end

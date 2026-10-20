class User < ApplicationRecord
  belongs_to :company
  has_secure_password
  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, presence: true, uniqueness: true
  validates :role, inclusion: { in: %w[admin member] }
  validates :password, length: { minimum: 12 }, if: -> { password.present? }

  def admin?
    role == "admin"
  end

  def self.dummy_password_digest
    @dummy_password_digest ||= BCrypt::Password.create("unused-demo-password").to_s
  end
end

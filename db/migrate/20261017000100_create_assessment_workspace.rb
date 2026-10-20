class CreateAssessmentWorkspace < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.string :name, null: false
      t.string :timezone, null: false, default: "London"
      t.timestamps
    end
    create_table :users do |t|
      t.references :company, null: false, foreign_key: true
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "admin"
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_check_constraint :users, "role IN ('admin', 'member')", name: "users_role_allowed"
    create_table :employees do |t|
      t.references :company, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email, null: false
      t.timestamps
    end
    add_index :employees, [:id, :company_id], unique: true
    create_table :assessments do |t|
      t.references :company, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :employee_email
      # Historical status is deliberately nullable. Enforcement is a separate rollout step.
      t.string :status
      t.jsonb :responses_json
      t.timestamps
    end
    add_foreign_key :assessments, :employees, column: [:employee_id, :company_id],
      primary_key: [:id, :company_id], name: "assessment_employee_company_matches"
  end
end

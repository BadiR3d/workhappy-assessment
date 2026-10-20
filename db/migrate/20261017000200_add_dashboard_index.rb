class AddDashboardIndex < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    execute "SET lock_timeout = '2s'"
    add_index :assessments, [:company_id, :created_at, :id],
      order: { created_at: :desc, id: :desc },
      name: "index_assessments_dashboard", algorithm: :concurrently
  ensure
    execute "RESET lock_timeout"
  end

  def down
    remove_index :assessments, name: "index_assessments_dashboard", algorithm: :concurrently
  end
end

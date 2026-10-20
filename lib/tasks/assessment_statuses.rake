namespace :assessment_statuses do
  desc "Install NOT VALID status check AFTER every writer is compatible; no historical backfill"
  task enforce: :environment do
    abort "Set STATUS_WRITERS_COMPATIBLE=true after draining incompatible writers." unless ENV["STATUS_WRITERS_COMPATIBLE"] == "true"
    connection = ActiveRecord::Base.connection
    name = "assessments_status_allowed"
    next if connection.check_constraints(:assessments).any? { |constraint| constraint.name == name }
    begin
      connection.execute("SET lock_timeout = '2s'")
      connection.execute("SET statement_timeout = '10s'")
      connection.add_check_constraint :assessments,
        "status IS NOT NULL AND status IN ('pending','in_progress','completed','needs_follow_up','archived')",
        name: name, validate: false
      puts "Status check installed for inserts/updates. Historical data is unchanged and unvalidated."
    rescue ActiveRecord::StatementInvalid
      abort "Constraint installation failed or timed out. Inspect locks and retry; no data backfill was run."
    ensure
      connection.execute("RESET lock_timeout")
      connection.execute("RESET statement_timeout")
    end
  end
end

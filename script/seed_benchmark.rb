# Run with bin/rails runner script/seed_benchmark.rb
abort "Benchmark seeding is development/test only." unless Rails.env.development? || Rails.env.test?
count = Integer(ENV.fetch("BENCHMARK_ROWS", "100000"), 10)
abort "Choose between 1000 and 1000000 rows." unless (1000..1_000_000).cover?(count)

company = Company.find_or_create_by!(name: "Benchmark Workspace") { |record| record.timezone = "London" }
employee = company.employees.find_or_create_by!(email: "benchmark@example.invalid") { |record| record.name = "Benchmark Employee" }
existing = company.assessments.count
now = Time.utc(2026, 10, 17, 12)
(existing...count).each_slice(1000) do |batch|
  Assessment.insert_all!(batch.map do |i|
    time = now - ((i * 7919) % 730).days - (i % 86400)
    { company_id: company.id, employee_id: employee.id, employee_email: employee.email,
      status: AssessmentStatus::VALUES[i % 5], responses_json: AssessmentScore::KEYS.to_h { |key| [key, i % 5] },
      created_at: time, updated_at: time }
  end)
end
puts "Benchmark workspace contains #{company.assessments.count} synthetic assessments."

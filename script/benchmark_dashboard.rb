# Run with bin/rails runner script/benchmark_dashboard.rb
# Uses an isolated temporary copy; never drops an application index.
require "benchmark"
require "json"
require "fileutils"
abort "Benchmark is development/test only." unless Rails.env.development? || Rails.env.test?
company = Company.find_by!(name: "Benchmark Workspace")
connection = ActiveRecord::Base.connection
row_count = company.assessments.count
abort "Run script/seed_benchmark.rb first (at least 1000 records)." if row_count < 1000
scope = company.assessments
filters = AssessmentFilters.new({ "from" => "2026-09-01", "to" => "2026-10-17" }, timezone: ActiveSupport::TimeZone[company.timezone])
query = AssessmentsQuery.new(scope: scope, filters: filters).call.order(created_at: :desc, id: :desc).limit(25)
# Keep the original table alias: the shared query includes both quoted and
# unquoted column references. Renaming only quoted identifiers breaks WHERE.
sql = query.to_sql.sub('FROM "assessments"', 'FROM pg_temp.benchmark_assessments AS assessments')
abort "Unexpected query shape; benchmark stopped." if sql == query.to_sql

def capture(connection, sql)
  3.times { connection.select_all(sql) }
  samples = 15.times.map { Benchmark.realtime { connection.select_all(sql) } * 1000 }
  {
    median_ms: samples.sort[samples.length / 2], samples_ms: samples,
    ids: connection.select_all(sql).map { |row| row["id"] },
    explain: connection.select_rows("EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT) #{sql}").flatten
  }
end

begin
  connection.execute("CREATE TEMP TABLE benchmark_assessments AS SELECT * FROM assessments")
  # Reproduce the relevant existing baseline index, not an artificially unindexed table.
  connection.execute("CREATE INDEX benchmark_company ON benchmark_assessments(company_id)")
  connection.execute("ANALYZE benchmark_assessments")
  before = after = nil
  ActiveRecord::Base.uncached do
    before = capture(connection, sql)
    connection.execute("CREATE INDEX benchmark_dashboard ON benchmark_assessments(company_id, created_at DESC, id DESC)")
    connection.execute("ANALYZE benchmark_assessments")
    after = capture(connection, sql)
  end
  abort "Result IDs/order changed." unless before[:ids] == after[:ids]
  result = { measured_at: Time.now.utc.iso8601, ruby: RUBY_VERSION, rails: Rails.version,
    postgres: connection.select_value("SELECT version()"), company_rows: row_count,
    table_rows: connection.select_value("SELECT count(*) FROM benchmark_assessments"),
    measurement: "SQL round-trip on a temporary copy, 3 warmups + 15 measured runs; not endpoint latency",
    filters: filters.to_h, sql: sql, before: before, after: after }
  FileUtils.mkdir_p(Rails.root.join("docs"))
  File.write(Rails.root.join("docs/benchmark-results.json"), JSON.pretty_generate(result) + "\n")
  ratio = before[:median_ms] / after[:median_ms]
  summary = <<~MARKDOWN
    Measured on #{result[:measured_at]} with Ruby #{RUBY_VERSION}, Rails #{Rails.version}, and #{result[:postgres]}.

    | Measurement | Before: company index | After: composite dashboard index |
    | --- | ---: | ---: |
    | Median SQL round-trip (15 runs) | #{before[:median_ms].round(3)} ms | #{after[:median_ms].round(3)} ms |

    Dataset: #{result[:table_rows]} total synthetic rows; #{row_count} in the measured tenant. Three warmups per case, identical date filters (2026-09-01 through 2026-10-17), newest-first ordering, and a 25-row limit. Rails query caching was disabled. Result IDs/order matched exactly. Before/after median ratio: #{ratio.round(2)}×. #{ratio > 1 ? "The indexed query was faster in this local experiment." : "This experiment did not show an improvement; investigate before submission."}

    This measures SQL round-trip time on a temporary table copy, not browser rendering, HTTP latency, or production load. Full samples and query plans are in [docs/benchmark-results.json](docs/benchmark-results.json).
  MARKDOWN
  solution_path = Rails.root.join("SOLUTION.md")
  solution = File.read(solution_path)
  marker = /<!-- BENCHMARK_RESULTS_START -->.*?<!-- BENCHMARK_RESULTS_END -->/m
  abort "Benchmark recorded, but SOLUTION.md result markers are missing." unless solution.match?(marker)
  File.write(solution_path, solution.sub(marker, "<!-- BENCHMARK_RESULTS_START -->\n#{summary}<!-- BENCHMARK_RESULTS_END -->"))
  puts "Before: #{before[:median_ms].round(3)} ms; after: #{after[:median_ms].round(3)} ms. Identical result IDs/order."
  puts "Evidence saved to docs/benchmark-results.json."
  puts "SOLUTION.md updated with measured results."
ensure
  connection.execute("DROP TABLE IF EXISTS pg_temp.benchmark_assessments")
end

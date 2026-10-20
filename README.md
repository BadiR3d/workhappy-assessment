# Workhappy assessment workspace

A small Ruby on Rails + PostgreSQL application for company admins to review seeded assessments, update statuses, and download a company-scoped CSV. TypeScript enhances the date controls with a custom calendar and adds export feedback. No questionnaire or answer-entry workflow is included.

## Verification status

Local verification: **36 tests, 211 assertions, zero failures/errors**; Rails autoload and TypeScript checks pass. The measured query improved from **12.610 ms to 0.245 ms median** on 100,000 tenant assessments, with identical result IDs/order. This is a local SQL benchmark, not whole-page latency. Dependency locks and the PostgreSQL schema are included. See [docs/VERIFICATION.md](docs/VERIFICATION.md) for evidence and remaining browser checks.

## Local setup

Requirements: Ruby **3.3.6**, Bundler, Node.js **22**, npm, and a running PostgreSQL **18** server (including client tools such as `pg_dump`). Rails is pinned to **8.1.4**. Install these through your normal runtime/package manager; the system Ruby is not sufficient.

```sh
# If using rbenv and ruby-build:
rbenv install -s 3.3.6
rbenv local 3.3.6
gem install bundler

# Start PostgreSQL through your usual service manager first.
# Optional if PostgreSQL requires explicit credentials/host:
export DATABASE_URL=postgresql://localhost/workhappy_development

npm run setup:dev
npm run start:dev
```

Open http://localhost:3000. `bin/setup` installs dependencies, builds TypeScript, prepares the database, and seeds fictional data. Without `DATABASE_URL`, Rails uses the local PostgreSQL socket and the `workhappy_development` database. `.env.example` is documentation; environment files are not automatically loaded.

`Gemfile.lock` and `package-lock.json` pin the resolved dependencies. `db/structure.sql` contains the generated schema, not assessment data. Keep all three in the submission. Never commit real secrets or database exports.

| Company | Email | Password |
| --- | --- | --- |
| Northstar Studio | `admin@northstar.example` | `Demo-assessment-2026!` |
| Fieldwork Collective | `admin@fieldwork.example` | `Demo-assessment-2026!` |

Seeds are refused in production. Each demo company has eight fictional employees with **four distinct assessments per employee** (32 rows per company). Visits are weeks apart and have different answer sets, scores and statuses. Missing/invalid answer examples occur only on the latest visit of the relevant employee. Running `bin/rails db:seed` upgrades the original marked one- or four-record fixture sets: existing IDs survive, and missing historical visits are added. Upgraded records and subsequent manual edits are preserved on later runs. Unmarked histories and the benchmark tenant are untouched. This is demo fixture maintenance, not a production backfill. Legacy status fixtures intentionally bypass model validation; seed before optionally installing the staged status check.

The latest Northstar visits show Alex Morgan (40/100), Sam Patel (0/100), and Taylor Reed (100/100). The latest Fieldwork visits show Priya Naidoo (20/100), Liam Jacobs (65/100), and Zanele Dlamini (30/100). Earlier visits have different dates, statuses and scores. For example, Alex’s newest-to-oldest scores are 40, 65, 90 and 10; Priya’s are 20, 40, 65 and 90. To refresh an existing demo installation, run `bin/rails db:seed` and reload the browser.

## What to try

1. Sign in to Northstar. Review the dashboard, date/status filters, score cases, and pagination.
2. Download CSV. It contains `employee,created_date,status,score`, one row per matching assessment. Employee is the displayed name; score is numeric from 0–100 or an explicit unavailable/incomplete label. Emails, raw answers and comments are excluded.
3. Open Review and save a canonical status. Unmapped historical records require an explicit choice.
4. Sign out and sign in to Fieldwork. Northstar's records must not be accessible.
5. Try `/assessments/export?company_id=123`. Unexpected filters are rejected, never used for access.

The score is the sum of five integers from 0–4 multiplied by five. Valid zero is `0 / 100`; incomplete answers show “Not yet scored”; malformed answers show “Score unavailable”. This is an invented demo formula, not an ergonomic or medical standard. See [scoring specification](docs/SCORING_SPEC.md).

## Checks

Use a separate test database. Do not point `TEST_DATABASE_URL` at development or production.

```sh
unset DATABASE_URL
export TEST_DATABASE_URL=postgresql://localhost/workhappy_test
RAILS_ENV=test bin/rails db:prepare
bin/rails test
bin/rails zeitwerk:check
npm run typecheck
npm run build
```

The integration tests cover tenant isolation, role checks, status saves, date boundaries, CSV redaction, and logs. Model tests cover database constraints and daylight-saving boundaries. CI provisions PostgreSQL and runs the Rails/TypeScript checks.

Pure Ruby checks can also run without Rails or PostgreSQL:

```sh
ruby -Itest -e 'Dir["test/unit/*_test.rb"].sort.each { |file| require File.expand_path(file) }'
```

## Performance measurement

```sh
npm run benchmark
```

The opt-in seed creates 100,000 synthetic rows in a separate benchmark company; change `BENCHMARK_ROWS` for another size. The measurement builds a temporary copy of the table, retains a baseline company index, then compares the same tenant/date/order query before and after adding the dashboard index. It never drops an application index. It checks identical result IDs/order, performs three warmups and fifteen timed queries per case, and saves SQL timings and `EXPLAIN (ANALYZE, BUFFERS)` output to `docs/benchmark-results.json`.

These are SQL round-trip timings, not browser or whole-endpoint timings. The command also updates the marked results section in SOLUTION.md with measured medians and dataset details. If the candidate index does not improve the measured query, investigate the plan rather than claiming a speedup. Results exist only after a successful run; they are not estimated.

## Deployment

See [SOLUTION.md](SOLUTION.md) for the release and recovery runbook. Production requires `DATABASE_URL`, `SECRET_KEY_BASE`, and `APP_HOST`. On Heroku, use Node.js then Ruby buildpacks so `npm run build` runs before serving the app. `Procfile` defines web and release commands. No deployment has been performed.

The status constraint is intentionally **not** in automatic release migrations. After every writer is compatible, install it explicitly:

```sh
STATUS_WRITERS_COMPATIBLE=true bin/rails assessment_statuses:enforce
```

This protects subsequent inserts/updates without validating or modifying historical records. The historical backfill and final validation are plan-only.

## Files

- `app/models/assessment_filters.rb`: strict date/status validation.
- `app/queries/assessments_query.rb`: shared authorized filtering.
- `app/services/assessment_score.rb`: pure, deterministic scoring.
- `app/services/assessments_csv.rb`: explicit export schema.
- `app/controllers/assessments_controller.rb`: dashboard, scoped status editing, and streaming.
- `db/seeds.rb`: fictional legacy examples.
- `script/`: optional dataset and reproducible benchmark.
- [SOLUTION.md](SOLUTION.md): implementation trade-offs and operations.
- [docs/DEMO.md](docs/DEMO.md): narrated demonstration checklist.

The application is self-contained in `assessment-app/`. The original PDFs and planning documents remain in the parent folder; a copy of the scoring specification is included in `docs/SCORING_SPEC.md`. Run setup and development commands from this application directory. No GitHub repository has been published and no video has been recorded.

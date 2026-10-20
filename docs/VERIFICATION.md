# Verification record

Updated 19 October 2026. This separates checks actually observed from owner-reported actions and remaining evidence.

## Current environment

Ruby 3.3.6, Rails 8.1.4 and their resolved gems are installed. Gemfile.lock, package-lock.json and db/structure.sql are present. The app owner confirmed browser login works after the boot-order and referrer-policy fixes.

The agent sandbox still cannot connect to the local PostgreSQL socket (`Operation not permitted`) or reach the running local web server. This does not mean the owner's terminal or browser is broken. Database and browser checks must run there or in CI.

## Executed and observed

| Check | Result |
| --- | --- |
| Pure score/filter/status/CSV tests | 14 tests, 84 assertions, zero failures/errors |
| Real Rails CSRF/session request tests, without database access | 3 tests, 8 assertions, zero failures/errors |
| Rails boot and eight-hour session setting | Passed |
| Rails autoload (`zeitwerk:check`) | Passed |
| Pinned TypeScript typecheck and build | Passed |
| Updated benchmark script syntax | Passed |
| README/SOLUTION/docs local links | No broken links |
| Schema content | No assessment/employee/user data INSERTs or COPY blocks |

The request tests verify acceptance of a valid same-origin logout form, rejection of tokenless/cross-origin login requests, and the `same-origin` referrer policy. They do not substitute for successful database-backed authentication.

## Full local verification supplied by the owner

Terminal output supplied on 19 October 2026 confirms:

- `npm run setup:dev`: databases created, both migrations completed, seeds loaded, TypeScript built successfully after the boot-order fix.
- `npm test`: **36 tests, 211 assertions, 0 failures, 0 errors, 0 skips** (seed 42912).
- `npm run zeitwerk:check`: all good.
- `npm run typecheck`: passed.
- Browser request log: successful login (303), dashboard (200), and assessment review pages (200). Earlier boot and null-origin errors in the transcript precede the successful run and are resolved.

This confirms setup on the owner's local machine; it is not a separate clean-checkout reproduction. The GitHub workflow has not been run.

## Performance evidence

The owner ran `npm run benchmark` successfully on 19 October 2026. The agent inspected [benchmark-results.json](benchmark-results.json), verified both 15-sample medians, and confirmed identical nonempty 25-record ID sequences.

- Dataset: 100,064 rows total; 100,000 in the measured tenant.
- Before median SQL round-trip: **12.610 ms**.
- After median SQL round-trip: **0.245 ms**.
- Ratio: **51.47×**, approximately **98.06%** less query time in this experiment.
- Plan: sequential scan plus top-N sort changed to a composite-index scan with no sort.
- Observed plan buffers: 3,264 local buffer reads before; 28 local buffer hits after. Cache behavior is part of this local result and the ratio is not a guaranteed production speedup.

SOLUTION.md includes the measured result. This is SQL round-trip evidence on an isolated temporary copy, not a whole-dashboard/browser latency claim.

The preparation review fixed a query-rewriting bug: the temporary table is now aliased as `assessments`, so both quoted and unquoted column references keep working. Cleanup targets `pg_temp` explicitly and cannot drop a permanent table with the same name.

## CSV update

The export now includes all four dashboard columns at the owner's request: employee name, created date, status and score. Emails/raw answers/comments remain excluded; employee name lookup is company-scoped per batch. Updated pure tests pass: 16 tests, 91 assertions, including CSV escaping, formula protection, zero and missing/invalid scores. Database-backed CSV assertions were updated and need a fresh full-suite run; the previous 36-test pass predates these changes.

## Date range update

Date controls are grouped and restyled, with maximum dates supplied by the server using the company's timezone. The shared filter validator rejects future dates for dashboard and CSV requests. TypeScript keeps start/end picker bounds consistent. TypeScript checks/build and the pure suite pass: 20 tests, 208 assertions. Added a database-backed regression for picker maximums and future-date rejection; a full suite rerun remains required. The empty-results test now uses an old date range, since future ranges are intentionally invalid.

## Remaining local checks

- Distinct demo histories (20 October): restored four visits per employee with different dates, answers, score outcomes and normalized statuses. Pure tests verify all 16 employee histories: **19 tests, 203 assertions, zero failures/errors** across the unit suite. Database seed tests now cover fresh creation, upgrades from one/four old fixtures, ID preservation and rerun stability. Database access remains sandbox-blocked, so apply with `bin/rails db:seed` in the owner's terminal and run `npm test` for those integration checks. Existing benchmark measurements remain evidence from their recorded dataset; the benchmark tenant is unchanged.

- After the filter-button fix, rerun `npm test`. The earlier 36-test result predates this change. The controller now ignores Rails' `commit` submit metadata while still rejecting unsupported filters. Two database-independent callback regression tests pass (4 assertions); a database-backed regression also verifies the rendered button submission returns only matching assessments.

- Complete [MANUAL_QA.md](MANUAL_QA.md), including the CSV download and responsive/keyboard checks. Login alone does not cover the full workflow.
- Verify setup from a clean checkout on a machine with Ruby 3.3.6 and PostgreSQL 18.

GitHub publication and the narrated video are intentionally left to the owner. Historical backfill and final constraint validation remain plan-only.

The date controls now use a styled calendar dialog with keyboard navigation and disabled future dates, retaining native inputs as the no-JavaScript fallback. The filter row uses one label baseline and equal-height controls. `npm run typecheck` and `npm run test:calendar` passed (4 calendar tests). Visual browser verification remains outstanding.

## CI seed isolation fix (20 October)

The reported CI run failed with duplicate demo-admin emails during test setup. Rails `db:prepare` seeds newly initialized databases by default, so the test database already contained the demo workspaces. CI now loads only the schema into its fresh PostgreSQL service database, and `config/database.yml` disables automatic seeding for the test database. Seed tests still explicitly load `db/seeds.rb` within test transactions. Rails boot confirms `seeds?` is false for test; workflow YAML parses and diff whitespace checks pass. A new CI run is needed to verify the full suite, including the two failures whose details were not included in the supplied log excerpt. Existing seeded local databases are not modified by this configuration change.

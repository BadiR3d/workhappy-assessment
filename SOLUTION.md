# Safely extending an assessment feature

## Context and implementation

The supplied folder contained a job specification and assignment, with no starter repository or scoring algorithm. This application is minimal scaffolding with synthetic legacy records. It is not a reconstruction of Workhappy's production application. There are no deliberately insecure endpoints in the final code.

The implemented slice provides session login, tenant-scoped assessment listing, two filter concepts, company-scoped streaming CSV, score calculation, and a small status edit screen. It uses Rails 8.1.4, PostgreSQL, server-rendered HTML, and small TypeScript modules. It does not collect assessment answers; seeds provide them.

Local verification is recorded in [docs/VERIFICATION.md](docs/VERIFICATION.md): **36 tests, 211 assertions, zero failures/errors**, with passing Rails autoload and TypeScript checks. The owner supplied successful setup, login/dashboard/review and benchmark output; the saved benchmark evidence was inspected separately. Ruby dependency locks and the database schema are included. Database-backed checks ran in the owner’s terminal because the agent sandbox cannot access the local PostgreSQL socket; no CI execution is claimed.

## Architecture and scope

Controllers coordinate requests. Active Record models own persistence and invariants. `AssessmentFilters` parses input, while `AssessmentsQuery` applies it to an already authorized relation. `AssessmentScore` is a pure function. `AssessmentsCsv` is an allowlist serializer. `AssessmentStatus` centralizes aliases. Narrow status normalization runs before validation on the current record only.

These objects provide useful separation without a repository wrapper, separate API, SPA, background worker, state-machine library, or full CQRS/hexagonal structure. The brief supplies permitted statuses, not transition rules. A full questionnaire, registration system, SSO, or employee CRUD would broaden the task unnecessarily.

## Tenant isolation and authentication

The user signs in with a bcrypt-backed password and receives a signed/encrypted Rails session cookie. Login resets the session. Cookies are HTTP-only, SameSite=Lax, expire after eight hours, and are secure in production. Writes use Rails CSRF protection. Sign-in attempts have a process-local rate limit; a shared store or ingress limit is needed across multiple web processes.

Every assessment action checks the current user's admin role and starts from `current_user.company.assessments`. No client company identifier is accepted. Cross-tenant record IDs return 404 and non-admin users receive 403. Status updates permit only `status`, preventing tenant or answer mass assignment. Employee lookup is also company-scoped; the initial demo schema includes a composite employee/company foreign key as well as model validation.

That initial schema migration is scaffolding for an empty database, not instructions to add and validate a foreign key across a large live legacy table. Existing production integrity would require a separate staged audit/constraint plan.

## Filters and exports

Exactly two filter concepts are exposed: creation-date range and canonical status. Unknown filter keys cause 422. Dates must be ISO dates from 1900-01-01 through today in the company’s timezone; future dates, reversed ranges and invalid statuses fail explicitly. Custom calendar dialogs use that same maximum, support keyboard navigation, and constrain the end date to be on or after the start. Native date inputs remain the fallback without JavaScript. Dates use the company's timezone (London in the seeds), with an inclusive end date represented by the exclusive midnight of the following local day. This handles daylight-saving transitions.

Dashboard and export use the same query. Status filtering recognizes canonical values and aliases after consistent ASCII whitespace/case normalization. `complete`, `comp`, and `done` map to `completed`. Unknowns appear only in unfiltered results; they are displayed as “Unmapped” and serialized as the fixed value `unmapped`. This is not a sixth permitted database status.

CSV fields are `employee,created_date,status,score`, matching the four dashboard columns as requested by the project owner. Employee names intentionally identify the displayed employee; they are personal information and this export is not anonymous. Emails, database IDs, raw answers and comments remain excluded. Scores use the same pure calculation as the dashboard, including legitimate zero and explicit incomplete/invalid labels. Employee names are CSV-escaped and formula-leading text is prefixed with an apostrophe for spreadsheet safety. Authenticated tenant access and private/no-store caching apply. This replaces the initial two-column design; the assignment’s exact two-filter requirement is unchanged.

Streaming avoids an export job model, storage credentials, file retention, polling and a worker. The controller loads the fields needed for scoring and traverses stable ID batches of 500. Each batch resolves employee names through a company-scoped query, avoiding per-row lookups and preventing a mismatched association from exposing another tenant’s employee. Raw responses are used only for score calculation and are never serialized. An initial maximum ID bounds later inserts; this is not snapshot isolation, and concurrent edits can change which records match. CSV order is ID order; dashboard order is newest creation date, then ID.

Authorization and filter checks happen before headers are committed. Streams close on completion/failure/disconnect. Logs contain sanitized event metadata. A failure after streaming begins can leave a partial CSV and cannot be replaced with a normal error page. TypeScript says only “Download requested”; it does not claim completion and does not buffer the file in a browser Blob. Native form errors remain readable server responses.

Trade-offs: exports occupy web capacity, the initial maximum-ID query must finish promptly, and large sparse filters can take longer than ordinary dashboard reads. Load-test before enabling on a busy installation. If export durations or concurrency are excessive, move this operation to a durable job with private expiring storage. Heroku's initial response and streaming-idle limits still apply; streaming is not a general timeout bypass. [Rails streaming](https://api.rubyonrails.org/v8.1.0/classes/ActionController/Live.html), [Heroku timeouts](https://devcenter.heroku.com/articles/request-timeout)

## Score correctness

The demo uses five equally weighted workstation questions. Each stored answer must be an integer from 0 to 4. Score = sum × 5; no rounding is needed. This is an illustrative formula, not Workhappy's rule or a clinically validated assessment.

All five valid answers produce an integer, including zero. Missing/null answers produce “Not yet scored”; malformed objects, wrong types or out-of-range answers produce “Score unavailable”. Invalid answers take precedence over missing ones. Comments and extra fields never affect scoring. Status and score are independent; completed records with missing answers are visibly not scored rather than assigned a fabricated zero.

The calculation is in one pure function and runs for the bounded page of records. No persisted score can become stale and no frontend formula can diverge. Test cases in docs/SCORING_SPEC.md cover the contract. Because there was no supplied implementation, this demonstrates correctness rather than claiming to diagnose an actual production scoring bug.

## Dashboard performance

The dashboard loads at most 26 assessments (25 displayed plus next-page detection), then one scoped employee query. It avoids per-row employee lookups and a full-table count. Pagination uses bounded offsets with a maximum page of 999; keyset navigation is a future improvement if deep browsing is needed. Filtering remains available beyond that navigation cap.

The targeted index is `(company_id, created_at DESC, id DESC)`. It supports the tenant equality predicate and the default date/order query. It is created concurrently outside a migration transaction with a short lock timeout. There is no speculative status-expression index. Status-filtered queries may benefit differently and should be measured separately before adding another index.

The benchmark script compares the real query against an isolated temporary copy with the baseline company index, then with the proposed composite index. It uses the same dataset, warms each case three times, takes fifteen samples, disables Rails query caching, and verifies identical result IDs/order. It saves median SQL round-trip times, plans/buffers, dataset sizes, engine versions and raw samples. The table-copy experiment does not measure HTTP/rendering latency or production load. It does not disable sequential scans or force the desired plan.

Run:

```sh
npm run benchmark
```

The command writes full evidence to `docs/benchmark-results.json` and updates the results below. Investigate if there is no improvement; the assignment requires a measured gain. [PostgreSQL concurrent indexes](https://www.postgresql.org/docs/current/sql-createindex.html)

<!-- BENCHMARK_RESULTS_START -->
Measured on 2026-10-19T16:50:18Z with Ruby 3.3.6, Rails 8.1.4, and PostgreSQL 18.3 (Homebrew) on aarch64-apple-darwin24.6.0, compiled by Apple clang version 17.0.0 (clang-1700.6.3.2), 64-bit.

| Measurement | Before: company index | After: composite dashboard index |
| --- | ---: | ---: |
| Median SQL round-trip (15 runs) | 12.61 ms | 0.245 ms |

Dataset: 100064 total synthetic rows; 100000 in the measured tenant. Three warmups per case, identical date filters (2026-09-01 through 2026-10-17), newest-first ordering, and a 25-row limit. Rails query caching was disabled. Result IDs/order matched exactly. Before/after median ratio: 51.47×. The indexed query was faster in this local experiment.

This measures SQL round-trip time on a temporary table copy, not browser rendering, HTTP latency, or production load. Full samples and query plans are in [docs/benchmark-results.json](docs/benchmark-results.json).
<!-- BENCHMARK_RESULTS_END -->

The saved plans explain the gain: the baseline chose a sequential scan and top-N sort; the composite index supplied matching rows in the required order without a sort. The baseline plan read 3,264 local buffers versus 28 local buffer hits afterwards. Those cache conditions contribute to the observed local result; the 51.47× ratio is not a promised production improvement.

## Logging

All request parameter values are filtered. The standard request-start logger is removed because its raw URL/query string lies outside parameter filtering. Active Record SQL logging is disabled to avoid bind values and database error details. There are no answer/object dumps or frontend console logs. Export events record request ID, counts and duration; failures record only the exception class. Database statement errors return a fixed message.

This sacrifices some troubleshooting detail intentionally for the narrow exercise. Hosting router logs and external exception/APM services are outside application parameter filtering; configure their query/payload capture and retention before live deployment. Do not send health information in URLs. The tests capture application logs and assert synthetic sensitive markers are absent. [Rails logging guidance](https://guides.rubyonrails.org/action_controller_advanced_topics.html#log-filtering)

## Status normalization

Allowed writes: `pending`, `in_progress`, `completed`, `needs_follow_up`, `archived`.

| Historical values | Handling |
| --- | --- |
| Canonical values | Preserve |
| Case/ASCII whitespace variants | Normalize |
| `complete`, `comp`, `done` | `completed` |
| null, blank, `n/a`, unknown strings | Leave historical value; require explicit review before save |

The model validates every ordinary save, including an unrelated edit. Known legacy values normalize on save; unknown values cause a helpful validation error. No unknown value is silently declared pending or completed. Production writers that use SQL, `update_all`, `insert_all`, or validation bypass must be audited; Rails callbacks are not universal enforcement.

`assessment_statuses:enforce` installs `CHECK (status IS NOT NULL AND status IN (...)) NOT VALID`. Null rejection must be explicit. The constraint immediately protects inserts and updates while leaving historical rows unscanned. An unrelated update to an invalid historical row will fail until its status is resolved. Installation itself needs a brief lock, so it has a two-second lock timeout and ten-second statement timeout. The task is deliberately separate from automatic release migrations. [PostgreSQL constraint staging](https://www.postgresql.org/docs/current/sql-altertable.html)

## Release runbook for an existing live application

The following is an operational plan; no hosted app or production database has been changed.

1. **Prepare while live:** inventory writers/status counts without dumping responses, confirm alias mapping, document unknowns, and test compatibility on synthetic or appropriately protected representative data. Confirm current readers tolerate canonical values. Select a known-good compatibility release as the rollback target. Resolve unknown-value editing policy with the product owner.
2. **Backup, preferably low traffic:** capture and verify a managed backup, record its ID/time and release version, and rehearse a restore into an isolated protected recovery database. Large logical backups use resources; monitor load. Commands below use placeholders, not real apps.
3. **Deploy compatibility code while live:** readers understand both status forms; writers normalize known values and reject ambiguous saves. Keep `ASSESSMENT_EXPORT_ENABLED=false` for the first smoke checks. Build TypeScript with the Node buildpack before Ruby startup. Set `APP_HOST`, `DATABASE_URL`, and a generated `SECRET_KEY_BASE`; verify HTTPS and private responses.
4. **Index at low traffic:** run the concurrent index migration, outside a transaction. It permits writes but consumes CPU/I/O and may wait for transactions. Monitor query latency and `pg_stat_progress_create_index`. If it fails, inspect `pg_index.indisvalid`; drop an invalid index concurrently and retry after fixing the cause. Do not use `IF NOT EXISTS` to mistake an invalid index for success. This may be scheduled as a supervised one-off migration rather than a long routine release phase.
5. **Drain old writers while live:** finish/restart web and worker processes running incompatible code. Audit direct SQL imports. Only then run `STATUS_WRITERS_COMPATIBLE=true bin/rails assessment_statuses:enforce`. The flag is an operator assertion, not automatic compatibility detection. On lock timeout, inspect long transactions and retry later; do not increase lock waiting indefinitely.
6. **Smoke-test while live:** two-tenant isolation, login/logout, date boundaries, invalid filters, CSV columns, score cases and canonical saves. Enable the export after checks. Monitor sanitized errors, query latency, database connections, memory and export durations/disconnects.
7. **Historical cleanup, PLAN ONLY:** obtain approved mappings. Start at low traffic with batches of approximately 500 primary keys, a checkpoint, short transactions, pause switch and throttling. Keep a restricted audit of old/new status and record ID for reversibility. Update only where the current status still matches the audited old value (`IS NOT DISTINCT FROM` handles null), and check version/timestamp where appropriate. Skip changed rows for re-review. Pause on lock waits, rising latency or replication lag. Unknowns remain unresolved until reviewed. Do not backfill inside a schema migration or release transaction.
8. **Final validation, PLAN ONLY:** after cleanup and a zero-invalid-row audit, schedule `VALIDATE CONSTRAINT assessments_status_allowed` at low traffic. It scans the table and consumes resources, though ordinary writes may continue. Only later retire compatibility aliases. Neither historical cleanup nor final validation is implemented as an automatic task.

```sh
heroku pg:backups:capture --app YOUR_APP
heroku pg:backups:info BACKUP_ID --app YOUR_APP
heroku pg:backups:restore YOUR_APP::BACKUP_ID DATABASE_URL --app ISOLATED_RECOVERY_APP
```

The backup ID must refer to a completed capture. Restore into an isolated recovery target first, verify counts/tenant relationships/status distributions and access controls, and rehearse application startup. Do not restore real employee health data into an ordinary public staging environment. [Heroku backup/restore](https://devcenter.heroku.com/articles/heroku-postgres-backups)

## Rollback and disaster recovery

- **Application fault:** disable exports, stop any later backfill process, and deploy the known-good compatibility release. Keep safe additive indexes/checks. Do not blindly reverse migrations or return to code that cannot read canonical statuses. Heroku release rollback does not reverse database writes.
- **Constraint incompatibility:** prefer fixing the incompatible writer. If removal is required for service recovery, first stop that writer and review the integrity trade-off, then remove only the named check under a short lock timeout. Do not remove tenant boundaries.
- **Bad historical mapping:** use the restricted old/new audit and conditional reversal so newer legitimate changes are not overwritten. A canonical `completed` value cannot identify whether it originally meant `done`, `comp` or `complete`; reversing by value alone is unsafe. This scenario is plan-only because the assignment does not execute a backfill.
- **Database disaster:** stop web writes, workers and external importers; capture the current state if possible. Restore the verified backup into a separate protected database, validate it, reconcile post-backup changes where possible, and switch connections during a controlled maintenance window. PGBackups restore deletes target contents and is not a partial merge. A direct restore loses post-backup writes unless recovered separately. Agree the recovery point/time with the owner before cutover.

## Submission readiness and AI use

The source, dependency locks, database schema, setup documentation, operational plan and demo script are supplied. GitHub publication and the narrated video are handled by the owner. Consult docs/VERIFICATION.md for outstanding evidence and manual checks. The implementation used AI assistance, with pure Ruby tests, Rails request tests, TypeScript compilation and static inspection used to check its output. Database-backed tests and performance results must be recorded from actual execution; unexecuted checks are not reported as passing.

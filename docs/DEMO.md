# Eight-minute narrated demo

Run the full verification checklist and benchmark before recording. Use synthetic data only. Record your own voice explaining the decisions and what the code actually does.

1. **0:00–0:45 — Scope.** Explain the missing starter code and invented demo scoring. Show the small Rails application and two fictional companies.
2. **0:45–2:00 — Dashboard.** Sign in to Northstar. Show 40/100, legitimate zero, missing and invalid answers. Explain the five-question sum × 5 and that no questionnaire was built. Apply date/status filters. Show an employee’s four distinct visits, then pagination across the 32 company assessments.
3. **2:00–3:15 — CSV.** Download and open the file. Show all four columns (employee name, created date, status, score) and the absence of emails, raw answers and comments. Demonstrate invalid filter feedback. Explain streaming, bounded batches and partial-download limitations.
4. **3:15–4:15 — Isolation.** Save a Northstar assessment URL. Sign out and into Fieldwork. Show the different dataset and denial of the Northstar URL. Demonstrate rejection of a forged company query parameter.
5. **4:15–5:15 — Code.** Trace controller authorization → scoped relation → shared filter/query object. Show the pure score function and explicit CSV allowlist.
6. **5:15–6:15 — Measurement.** Show actual benchmark output, matching result IDs/order, and before/after query plans. Explain the composite index and distinguish SQL timings from HTTP latency. Do not narrate a claimed speedup without running it.
7. **6:15–7:15 — Statuses.** Show a known alias displayed as completed and an unmapped historical value requiring review. Save a canonical status. Explain the separate NOT VALID check and why it waits for compatible writers.
8. **7:15–8:00 — Release/recovery.** Walk through backup verification, staged enforcement, plan-only historical batches and compatible rollback. Show test results and describe remaining limitations honestly.

Before sharing: confirm README setup works in a clean checkout; commit dependency locks and benchmark evidence; create a single GitHub repository with the intended visibility; record/upload a 5–10 minute video and add its link to the submission. The recording and publication have not been performed by this implementation.

# Final browser checks

Run `npm run start:dev` and open http://localhost:3000. These checks are not marked passed until actually observed in a browser. Use only the seeded fictional data.

| Check | Expected result | Observed |
| --- | --- | --- |
| Northstar login | Dashboard opens with Northstar Studio in the header | Pass Manual Testing |
| Fieldwork login | Priya Naidoo 20/100, Liam Jacobs 65/100, Zanele Dlamini 30/100; different names/dates/statuses from Northstar | Pass Manual Testing |
| Wrong password | Clear inline message; no session granted | Pass Manual Testing |
| Known score | Alex Morgan shows 40/100 | Pass Manual Testing |
| Valid zero and maximum | Sam Patel shows 0/100; Taylor Reed shows 100/100 | Pass Manual Testing |
| Missing and malformed answers | Robin Clarke shows Not yet scored; Casey Adams shows Score unavailable | Pass Manual Testing |
| Date/status filters | Only matching records; completed includes historical aliases | Pass Manual Testing |
| Empty results | Use an old empty range, such as 1900-01-01 to 1900-01-02; a useful empty state appears | Recheck — owner marked the previous future-range expectation passed; future dates are now rejected |
| CSV download | Exactly employee,created_date,status,score; employee names and scores match the dashboard; dates/statuses match filters; no emails/raw answers/comments | Recheck — owner marked the previous two-column expectation passed |
| Empty CSV | Apply 1900-01-01 to 1900-01-02: Export CSV is disabled and an explanation appears. Clear filters: export is enabled again. Direct `/assessments/export?from=1900-01-01&to=1900-01-02` still returns headers only | Pass Manual Testing |
| Invalid range | From later than To is prevented by the calendar; a manually edited URL with from later than to is rejected by the server | Pass reported by owner; recheck prevention in the new calendar | Pass Manual Testing |
| Company isolation | Copy a Northstar Review URL, sign into Fieldwork, open it: 404 | Pass Manual Testing |
| Forged export scope | `/assessments/export?company_id=123` returns a filter error | Pass Manual Testing |
| Status save | Review → select approved status → save → new status persists | Pass Manual Testing |
| Unmapped historical status | Useful explanation; explicit valid selection required | Pass Manual Testing |
| Pagination | Next/Previous preserve active filters and show the expected rows | Pass Manual Testing |
| Logout | Dashboard redirects to login afterwards | Pass Manual Testing |
| Keyboard | Visible focus, usable fields/buttons, reachable table region | Pass Manual Testing |
| Narrow viewport | Controls remain usable; table scrolls rather than breaking the page | Pass Manual Testing |
| Future-date limits | Today is selectable; tomorrow and later dates cannot be selected in either calendar. A dashboard or export URL with a future from/to date is rejected | Pass Manual Testing |
| Calendar navigation | Previous/next month and month/year menus work; unavailable months are disabled; selecting a day updates the correct field and closes the dialog | Pass Manual Testing |
| Calendar range and clearing | End cannot precede start; start cannot follow end. Clear date clears only that field and releases its bound on the other picker; Today respects the other bound | Pass Manual Testing |
| Calendar keyboard and dismissal | Enter/Space opens; arrows move days, Home/End move within the week, PageUp/PageDown move months. Tab stays in the dialog; Escape/close returns focus to the opening control | Pass Manual Testing |
| Filter combinations and reset | From-only, To-only, same-day and date-plus-status filters work. Values survive Apply/refresh; Clear resets both dates and status | Pass Manual Testing |
| CSV across pages and companies | With no filters, CSV includes all 32 demo assessments, not just the current page. Each login exports only its own company; active filters also apply to export from page two | Pass Manual Testing |
| Distinct demo history | Each company has 32 assessments: four visits per employee with distinct dates, scores and statuses, including the documented missing/invalid cases | Pass Manual Testing |
| Signed-out direct access | After logout, opening a saved Review URL or export URL redirects to login without showing assessment data or downloading a CSV | Pass Manual Testing |
| Updated filter layout | From date, To date and Status labels align; controls have equal heights. On a narrow viewport the row wraps without overlap and the calendar remains usable | Pass Manual Testing |
| JavaScript fallback | With JavaScript disabled and the page reloaded, native date fields, Apply filters and CSV download still work | Pass Manual Testing |

Do not include screenshots or exports with real employee data in the submission. The seeded demo credentials are listed in README.md.

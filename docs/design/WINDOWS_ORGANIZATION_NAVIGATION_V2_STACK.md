# Windows Organization Navigation v2 stack

This work is intentionally stacked for review and rollback safety:

1. `main`
2. PR #239 — Android direct-manipulation root paging
3. PR #240 — Organization management-area state lift
4. Windows Organization Navigation v2 — desktop presentation projection

The Windows layer depends on the state boundary established by PR #240 and should not be reviewed as an independent replacement for that state model.

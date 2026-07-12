---
name: query
description: Run a read-only SQL query against Summation data and render the result as a table. Use for quick data questions, sanity checks, or when the user provides SQL or asks something answerable with one query.
argument-hint: <sql or data question> [--limit N]
---

# Summation Query

Execute bounded, read-only SQL via the public query API.

**MCP-first**: when the `summation` MCP server is connected, use its query tool (same bounded, read-only semantics) instead of the REST call below; for open-ended data questions prefer `ask_analyst` (buffered result, ~15-60s — tell the user Addison is working). Helper fallback: `../api/scripts/sum_api.py`. The `/v1/...` path below is illustrative — if a call returns 404, the route may have moved — rediscover via `operations`/`operation` (the contract is the source of truth).

## Flow

1. If the user gave a question rather than SQL, ground it first: `/addison-internal:catalog <term>` (or `call GET /v1/tables`) to find real table names — never guess table names.
2. Execute:

```bash
python3 ../api/scripts/sum_api.py call POST /v1/query-executions \
  --body '{"sql": "<SQL>", "limit": <N, default 100, max 10000>, "timeout_ms": 30000}'
```

3. Render the result as a compact markdown table. State the row count and whether results were truncated by the limit.

## Rules

- The API is structurally read-only (every query is wrapped in `SELECT … LIMIT`); INSERT/UPDATE/DELETE will be rejected — tell the user that, don't retry.
- Always pass an explicit `limit`; ask before exceeding 1000 rows.
- Show the executed SQL with the results so the user can spot-check it (analyst-grade transparency).
- On error, surface the `request_id` and the SQL that failed. A `permission_denied: "User is not assigned to any role"` means the signed-in user's tenant lacks query roles — surface that message; it is not broken auth.

---
name: validate
description: Verify a Summation report against its sources before sharing — runs the report verification pipeline and summarizes verdicts and citations. Use before any report goes to an executive or external recipient, or when the user asks "is this right?".
argument-hint: <report id or name> [--project <name|id>]
---

# Summation Validate

Validation is a first-class ritual: nothing should reach an executive without it.

**MCP-first**: when the `summation` MCP server is connected, use its `validate_report` tool instead of the REST call below. It returns one buffered result (~15-60s) — tell the user validation is running; do not treat silence as failure before ~120s. Helper fallback: `../api/scripts/sum_api.py`.

## Flow

1. Resolve project and report: `call GET /v1/projects`, then `call GET /v1/projects/<PID>/reports`; match by id or name (newest first when ambiguous).
2. Run verification (streams SSE):

```bash
python3 ../api/scripts/sum_api.py call --stream \
  POST /v1/projects/<PROJECT_ID>/reports/<REPORT_ID>/verifications
```

3. Summarize the stream for the user as a verdict panel:
   - **Checked claims**: how many verified / flagged / unverifiable
   - **Flagged items**: each with the claim, why it was flagged, and the cited source
   - **Overall**: safe to share, share with caveats, or fix first

## Rules

- Never soften flagged findings — list them verbatim before any overall judgment.
- If verification itself fails, report the `request_id` and stop; do not declare the report valid.
- Pair with `/addison-internal:report`: after a successful generation, offer validation proactively.

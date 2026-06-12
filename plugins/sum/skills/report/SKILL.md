---
name: report
description: Generate a Summation report from a question and export it (Markdown, PDF, or DOCX). Use when the user asks for an analysis, report, board update, or exportable document over their Summation data.
argument-hint: <question> [--project <name|id>] [--format markdown|pdf|docx]
---

# Summation Report

Run the full pipeline: resolve project → generate report (streamed) → export artifact. Helper: `../api/scripts/sum_api.py` (sibling `api` skill).

## Flow

1. **Resolve the project.** `call GET /v1/projects`; match the user's `--project` by name or id. If they gave none and exactly one project exists, use it; otherwise list names and ask.
2. **Check the body schema first** (it evolves): `describe generate_report_v1_projects__project_id__reports_generations_post`. Build the body from the user's question.
3. **Snapshot, then generate (streams SSE).** First record the existing report ids: `call GET /v1/projects/<PROJECT_ID>/reports`. Then:

```bash
python3 ../api/scripts/sum_api.py call --stream \
  POST /v1/projects/<PROJECT_ID>/reports/generations \
  --body '<JSON per the described schema>'
```

   Take the report id from the stream events. If the stream didn't expose it, list reports again and use the id that is **new versus your snapshot** — never blind-take the newest entry (in shared projects a concurrent run's report can land in between). If zero or multiple new ids appear, stop and ask the user which report is theirs.

4. **Export.** Default format: `markdown` unless the user asked otherwise.
   - Markdown (text-safe): `call GET /v1/projects/<PID>/reports/<RID>/content --query '{"format":"markdown"}'`
   - PDF/DOCX (byte-safe — never print to stdout): `call GET /v1/projects/<PID>/reports/<RID>/content --query '{"format":"pdf"}' --output ./<report-name>.pdf`
5. **Report back**: report title/id, the saved file path (or inline markdown if short), and suggest `/sum:validate` before the user shares it externally.

## Rules

- Long generation is normal (minutes). Stream rather than poll; in Claude Code pair with a background shell if needed.
- Never paste raw `<sm-cite>`-style internal markers to the user; exports already strip them — prefer exported content over raw.
- On any failure, include the `request_id` from the error body and check `audit --tail 5` for the failing call.
- Pass `--profile <name>` on every helper call when the user named an environment; permission errors often mean wrong active profile, not broken auth.

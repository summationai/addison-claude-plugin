---
name: schedule
description: Schedule recurring Summation playbook runs with email delivery — list, create, pause, resume, or trigger schedules. Use when the user wants a report/playbook on a cadence ("every Monday", "daily at 9am") or asks what's scheduled.
argument-hint: "[list | run | pause | resume | create <playbook> ...]"
---

# Summation Schedule

Recurring playbook runs, delivered by email.

**MCP-first**: when the `summation` MCP server is connected, use its schedule tools (`list_schedules`, `create_schedule`, pause/resume/run-now) instead of the REST calls below — the same confirmation rules apply, and `create_schedule`'s own description requires confirming recipients + cadence first. Helper fallback: `../api/scripts/sum_api.py`. Clean operationIds exist: `list_schedules`, `create_schedule`, `show_schedule`, `update_schedule`, `delete_schedule`, `pause_schedule`, `resume_schedule`, `list_schedule_runs`, `run_schedule_now`.

## Flows

**Inspect**: `call GET /v1/schedules` → render a table: description, kind, cadence (+ timezone), target, status. For one schedule's history: `call GET /v1/schedules/<id>/runs`.

**Create** (the main event):
1. Schedules target **playbooks** today (`kind: "playbook"`). Find the target: `call GET /v1/projects/<PID>/playbooks`. If the user has no playbook for what they want, say so — `/addison-internal:report` is for one-off reports; a playbook must exist first.
2. `describe create_schedule` for the current schema, then build the body: target (`playbook_id`, `project_id`), `schedule` (`type` daily/weekly/…, `time_of_day`, **explicit `zone_id`** — ask for the user's timezone, never assume), `config` (`email_recipients` with to/cc/bcc, optional `output_folder`, `params`).
3. **Confirm before creating — this is an outward-facing action.** Echo back: what runs, when (with timezone), and exactly who receives email. Create only after an explicit yes.
4. `call POST /v1/schedules --body '<…>'` → report the schedule id and first expected run.

**Operate**: `pause`/`resume` via `call POST /v1/schedules/<id>/pause|resume`; immediate trigger via `call POST /v1/schedules/<id>/runs` (confirm first — it emails recipients now). Delete requires the user to name the exact schedule, confirmed.

## Rules

- Recipient lists are the blast radius: read them back verbatim before create/run-now; never add recipients the user didn't name.
- Always show cadence with its timezone; "9am" without a zone is a bug.
- On errors surface the `request_id`; check `audit --tail 5`.

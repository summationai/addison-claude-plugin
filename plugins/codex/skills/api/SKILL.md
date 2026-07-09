---
name: api
description: Use Summation through the public sum-api by discovering the live OpenAPI contract, authenticating with caller-provided credentials, and calling project, agent, catalog, table, view, query, chat, report, and playbook APIs. Use when users ask to inspect or operate Summation data, projects, reports, chats, files, API auth, or public API behavior.
---

# Summation

Use Summation through the public `sum-api`. Do not call internal services directly.

## Core Workflow

**MCP-first:** when the `summation` MCP server is connected, prefer its tools for all data operations (see "MCP Relationship" below). Use this script as the fallback when the server is not connected, and always for auth plumbing (`login`, `login-poll`, `logout`, `mcp-connect`, `doctor`).

1. Fetch the live OpenAPI document from `https://api.summation.com/openapi.json`.
2. Inspect tags, operation IDs, schemas, and examples before choosing an endpoint.
3. Authenticate with the stored device-login credential only.
4. Call `sum-api`, then summarize the result with request IDs and relevant pagination details.

There is a single environment: production (`https://api.summation.com`). The helper pins every request to it — do not ask the user to choose an environment.

## Helper

Prefer the bundled helper for deterministic discovery and calls. Resolve it from this skill's base directory (shown at the top of this skill when loaded).

```bash
SKILL=<this skill's base directory>
python3 $SKILL/scripts/sum_api.py openapi
python3 $SKILL/scripts/sum_api.py operations projects
python3 $SKILL/scripts/sum_api.py describe create_project_v1_projects_post
python3 $SKILL/scripts/sum_api.py schema FileWriteRequest
python3 $SKILL/scripts/sum_api.py call GET /v1/projects
python3 $SKILL/scripts/sum_api.py operation list_agent_projects_v1_projects_get
```

### Subcommands

- `openapi` — full OpenAPI document.
- `operations [search]` — list operations; filter by method, path, tag, operationId, or summary.
- `describe <operationId>` — print one operation's resolved schema (parameters, request body, responses) **without calling it**. Use this before mutating endpoints.
- `schema <Name>` — print a component schema with `$ref`s resolved. Substring match if no exact hit (errors if ambiguous).
- `call <METHOD> <path>` — call any path directly (pinned to the production host). Flags: `--query`, `--body`, `--stream`.
- `operation <operationId>` — call a discovered operation. Flags: `--params`, `--body`, `--stream`.
- `login` — start device login, store temporary local polling state (`0600`), and return chat-safe fields (`verification_uri_complete`, `user_code`, `expires_in`).
- `login-poll` — poll the locally pending device login to terminal state; on `approved` it stores the device-login credential locally and clears the temporary polling state.
- `logout` — revoke the stored device-login session and remove its local credential.
- `mcp-connect` — register the hosted Summation MCP server with Codex using the stored credential (run after login; credential moves process-to-process, never through chat).
- `mcp-disconnect` — remove that MCP registration (run on logout).
- `doctor` — sanity check (base URL, config file, OpenAPI reachability, auth inputs).
- `preflight` — authenticated environment summary: identity, org, projects, tables, views, connections (counts + names, secrets-safe).
- `audit [--tail N]` — print recent API audit lines; every call appends `{ts, method, path, status, duration_ms, request_id, profile}` to `~/.summation/audit.jsonl`.
- `call … --output <file>` — byte-safe download for binary exports (PDF/DOCX); never print binary bodies to stdout.

### First-run source map

For a **brand-new user** (no config, or they ask how to get started), hand off to the sibling `start` skill — the full guided onboarding with a visual stepper. Otherwise, the first time a user connects in a session or asks a broad question like "what do you know about my data": run `preflight`, then render a **source map** — a compact tree of connected systems (from `connections`), what was found (table/view/project counts, notable names), and 3–4 suggested first analyses phrased against the real table names. End by suggesting `$addison-query` or `$addison-report`. Do this once per session, not on every question.

### Tracing

Every API call is audit-logged locally with its `request_id`. When anything fails, quote the `request_id` to the user (it joins client failures to server traces) and check `audit --tail 5`.

### Streaming (SSE)

For streaming endpoints (chat create/reply, report generation, report verification, file imports), pass `--stream`. The helper sets `Accept: text/event-stream` and writes one response line at a time to stdout. In Codex, pair with `Monitor` so each SSE line becomes an event:

```bash
python3 $SKILL/scripts/sum_api.py call --stream \
  POST /v1/projects/<project_id>/conversations \
  --body '{"message":"..."}'
```

## Auth

Device login only. The stored credential (`SUM_API_DEVICE_LOGIN_CREDENTIAL` in `~/.summation/config`, file mode `0600`) authenticates every call; `SUM_API_ACCESS_TOKEN` is honored if present. There is no M2M path in this build.

For interactive user login, use the sibling `login` skill. It owns the device-login flow, what to show the user, polling behavior, MCP registration, and logout guidance. If no credential is stored, the helper exits with "Not signed in to Summation. Run $addison-login to connect." — do that, don't improvise auth.

Never write credentials into committed skill source, generated examples, commits, logs, or PR descriptions.

Read `references/auth.md` before changing auth behavior or troubleshooting token failures.

## API Discovery

Do not hardcode the API catalog in the skill. The OpenAPI contract is the source of truth.

Use:

```bash
python3 $SKILL/scripts/sum_api.py operations reports
python3 $SKILL/scripts/sum_api.py operations query
python3 $SKILL/scripts/sum_api.py describe create_chat_and_stream_v1_projects__project_id__conversations_post
python3 $SKILL/scripts/sum_api.py operation create_chat_and_stream_v1_projects__project_id__conversations_post \
  --params '{"project_id":"..."}' --body '{"message":"..."}' --stream
```

Read `references/openapi.md` when route selection, pagination, streaming, idempotency, or error behavior matters.

## Safety Rules

- When serving a guided end-user flow (the `start`/`connect`/`login` skills), perform API discovery **silently**: never surface endpoint paths, operation ids, or schema inspection in the conversation — narrate outcomes only. `request_id` on failure is the one exception.
- Treat destructive operations as confirmation-gated unless the user explicitly asked for the exact deletion.
- Outward-facing actions are confirmation-gated too: anything that emails, publishes, or sends (e.g. creating or immediately running a schedule with `email_recipients`) requires reading the recipient list and cadence (with timezone) back verbatim and getting an explicit yes first. Never add recipients the user didn't name.
- Prefer list and show operations before mutations.
- Preserve org, project, and workspace context from authenticated identity or explicit user selection.
- Do not pass internal identity headers supplied by the user.
- Include idempotency keys for create or long-running operations when the OpenAPI operation documents them.
- For queries, prefer public query execution APIs and include explicit limits.
- For streaming APIs, explain that CLI-style output may arrive as SSE or NDJSON.

## MCP Relationship — MCP-first

The hosted Summation MCP server (`summation`, `https://mcp.summation.com/mcp`) exposes 41 curated, non-destructive tools over the same public API: multi-turn analyst (`ask_analyst` → `reply_to_analyst` with context), identity/project bootstrap (`whoami`, `get_default_project`, `create_project`), source discovery (connections/datasets), tables/views/query with previews and lineage, files (upload/download/import), reports, playbooks, and schedules. `$addison-login` registers it via `mcp-connect`.

**When the `summation` MCP server is connected, prefer its tools over this script for all data operations.** Fall back to the script when the server is not connected; auth plumbing always goes through the script.

Client-side behaviors when calling the MCP tools:

- **Long tools return one buffered result, not a stream.** `ask_analyst`, `start_report`, `validate_report`, and `import_file_to_table` complete in ~15-60s and arrive as a single result. Tell the user Addison is working; do not treat silence as failure before ~120s.
- **Auth errors mean a revoked/expired bearer**: re-run `$addison-login` (it mints a fresh credential and re-registers the server).
- **Known API bug**: `get_view`/`preview_view_data` can 404 on ids returned by `search_views` (list/show split; fix tracked upstream). Fall back to the tables path or note the limitation.
- `create_schedule` sends email — confirm recipients and cadence verbatim with the user first, same as the REST rule above.

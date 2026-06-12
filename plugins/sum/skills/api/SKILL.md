---
name: api
description: Use Summation through the public sum-api by discovering the live OpenAPI contract, authenticating with caller-provided credentials, and calling project, agent, catalog, table, view, query, chat, report, and playbook APIs. Use when users ask to inspect or operate Summation data, projects, reports, chats, files, API auth, or public API behavior.
metadata:
  short-description: Work with Summation through sum-api
---

# Summation

Use Summation through the public `sum-api`. Do not call internal services directly.

## Core Workflow

1. Determine the environment from the user or `SUM_API_BASE_URL`.
2. Fetch the live OpenAPI document from `{SUM_API_BASE_URL}/openapi.json`.
3. Inspect tags, operation IDs, schemas, and examples before choosing an endpoint.
4. Authenticate with caller-provided credentials only.
5. Call `sum-api`, then summarize the result with request IDs and relevant pagination details.

Default base URL:

```bash
https://sandbox-api.summation.com
```

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
- `call <METHOD> <path>` — call any path directly. Flags: `--query`, `--body`, `--stream`.
- `operation <operationId>` — call a discovered operation. Flags: `--params`, `--body`, `--stream`.
- `token` — print a fresh M2M access token (for piping into `curl`).
- `configure` — write a local `.summation-config` (mode `0600`).
- `profiles` — list named profiles in `.summation-config` with secrets redacted.
- `use-profile <name>` — set the active profile in `.summation-config`.
- `doctor` — sanity check (base URL, config file, OpenAPI reachability, auth inputs).
- `preflight` — authenticated environment summary: identity, org, projects, tables, views, connections (counts + names, secrets-safe).
- `audit [--tail N]` — print recent API audit lines; every call appends `{ts, method, path, status, duration_ms, request_id, profile}` to `~/.summation/audit.jsonl`.
- `call … --output <file>` — byte-safe download for binary exports (PDF/DOCX); never print binary bodies to stdout.

Every API-facing subcommand accepts `--profile <name>` to use a named profile for that call.

### First-run source map

The first time a user connects (right after `login` succeeds) or when they ask a broad question like "what do you know about my data": run `preflight`, then render a **source map** — a compact tree of connected systems (from `connections`), what was found (table/view/project counts, notable names), and 3–4 suggested first analyses phrased against the real table names. End by suggesting `/sum:query` or `/sum:report`. Do this once per session, not on every question.

### Tracing

Every API call is audit-logged locally with its `request_id`. When anything fails, quote the `request_id` to the user (it joins client failures to server traces) and check `audit --tail 5`.

### Streaming (SSE)

For streaming endpoints (chat create/reply, report generation, report verification, file imports), pass `--stream`. The helper sets `Accept: text/event-stream` and writes one response line at a time to stdout. In Claude Code, pair with `Monitor` so each SSE line becomes an event:

```bash
python3 $SKILL/scripts/sum_api.py call --stream \
  POST /v1/projects/<project_id>/conversations \
  --body '{"message":"..."}'
```

## Auth

Ask the user to drop the `.summation-config` that you can copy over to the $SKILL folder or ask user to point to a file that contains `SUM_API_BASE_URL`, `SUM_API_CLIENT_ID` and `SUM_API_CLIENT_SECRET`.

The config can hold multiple tenant profiles:

```bash
SUM_API_ACTIVE_PROFILE=fanatics-sandbox

[profile.fanatics-sandbox]
SUM_API_BASE_URL=https://sandbox-api-fanatics.summation.com
SUM_API_CLIENT_ID=...
SUM_API_CLIENT_SECRET=...
SUM_API_M2M_SCOPE="agent:read agent:write"

[profile.shared-prod]
SUM_API_BASE_URL=https://api.summation.com
SUM_API_CLIENT_ID=...
SUM_API_CLIENT_SECRET=...
SUM_API_M2M_SCOPE="agent:read agent:write"
```

Use:

```bash
python3 scripts/sum_api.py profiles
python3 scripts/sum_api.py use-profile fanatics-sandbox
python3 scripts/sum_api.py call --profile shared-prod GET /v1/projects
```

Never write credentials into committed skill source, generated examples, commits, logs, or PR descriptions.

If credentials should persist locally, use:

```bash
python3 scripts/sum_api.py configure
```

This writes `~/.summation/skill-config` with file mode `0600`. The helper loads settings in this order: environment variables, explicit `SUM_API_CONFIG_FILE`, current directory `.summation-config`, `~/.summation/skill-config`, then legacy locations (installed skill `.summation-config`, home `~/.summation-config`). A config found only in a legacy location is migrated to `~/.summation/skill-config` on first use; the legacy file is left in place.

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

- Treat destructive operations as confirmation-gated unless the user explicitly asked for the exact deletion.
- Prefer list and show operations before mutations.
- Preserve org, project, and workspace context from authenticated identity or explicit user selection.
- Do not pass internal identity headers supplied by the user.
- Include idempotency keys for create or long-running operations when the OpenAPI operation documents them.
- For queries, prefer public query execution APIs and include explicit limits.
- For streaming APIs, explain that CLI-style output may arrive as SSE or NDJSON.

## MCP Relationship

If a hosted Summation MCP server is available, prefer MCP tools for structured execution. Otherwise use this skill plus live OpenAPI discovery to reach the same public API surface.

# Addison — Summation's AI analyst in Claude Code

Plugin marketplace for Summation. One plugin, `addison`, brings Addison to Claude Code and Claude Desktop: data questions over the hosted Summation MCP server, report generation and export (PDF/DOCX/Markdown), catalog discovery, bounded SQL.

## Install

**Claude Code (CLI/IDE):**

```
/plugin marketplace add summationai/addison-plugin
/plugin install addison@summation
```

Then `/addison:login` — one browser sign-in connects both the API credential and the Summation MCP server. (Once browser-based OAuth ships server-side, this becomes `/mcp` → sign in.)

**claude.ai / Claude Desktop (org admins):** Admin console → Plugins → Add plugins → *Sync from GitHub* (this repo) or *Upload a file* (`dist/addison-plugin.zip`). Members then install from the org library.

> Desktop note: skill scripts run in the code-execution sandbox. The org's code-execution network egress must allow the sum-api host(s) (Capabilities → Code execution), and credentials must be reachable from the sandbox — see the dogfood matrix in the rollout doc.

> Codex support is deferred — it will be rebuilt cleanly in a future release.

## Contents

| Skill | Invoke | Does |
|---|---|---|
| `start` | `/addison:start` | **guided onboarding**: visual stepper → connect → source map → meet Addison → suggested reports → run one on confirm |
| `api` | model-invoked | OpenAPI-discovery workflow + `scripts/sum_api.py` helper (canonical; sibling skills reference it); first-run source map |
| `login` | `/addison:login` | conversational credential setup → `~/.summation/summation-config` (0600) |
| `logout` | `/addison:logout` | remove the stored device-login credential from the active or selected profile |
| `doctor` | `/addison:doctor` | connectivity/auth diagnosis + `preflight` environment summary |
| `report` | `/addison:report` | generate a report from a question → export markdown/PDF/DOCX |
| `validate` | `/addison:validate` | run report verification; verdict panel before anything ships externally |
| `query` | `/addison:query` | bounded read-only SQL → rendered table, SQL shown for spot-checking |
| `catalog` | `/addison:catalog` | search/describe tables, views, catalog metadata |
| `connect` | `/addison:connect` | add a data source in-flow: non-secret config in chat, secret via local file (never in conversation), create + test |
| `schedule` | `/addison:schedule` | recurring playbook runs with email delivery: list/create/pause/resume/run-now (recipient lists confirmed verbatim) |

Every API call is audit-logged to `~/.summation/audit.jsonl` (`{ts, method, path, status, duration_ms, request_id, profile}`) — `sum_api.py audit --tail 20` to inspect.

Credentials never live in this repo. `.summation-config*` is ignored and must stay that way.

## Org announcement template

> **Summation is now in Claude.** Open a new chat and type **/addison:start** — it walks you through connecting (2 minutes), shows a map of your data, introduces Addison, and runs your first report. Already connected? Just ask data questions, or use /addison:report, /addison:query, /addison:catalog, /addison:validate.

## For agent harnesses (customer `AGENTS.md` snippet)

Drop this into a repo's `AGENTS.md`/`CLAUDE.md` where agents should prefer Summation:

```md
When working on data analysis, metrics, or report commentary, use the Summation
plugin first (catalog discovery before SQL; never guess table names). Prefer
exported report content over raw internals, cite request_ids on failures, and
run /addison:validate before any report is shared externally. Drafts need explicit
user approval before publishing anywhere.
```

## Editions

`plugins/addison` (external, source of truth) ships to the public marketplace: production-pinned, device-login only, host-pinned HTTPS requests. `plugins/addison-internal` is **generated** by `./build-editions.sh` — same skills with `EDITION="internal"` baked into the helper (any environment, M2M, profiles) plus the overlays in `internal/overlay/`. Never edit generated plugin directories directly.

The edition is a build-time constant, not an env var, so the external artifact contains no unlock path.

## Dev loop

```bash
claude --plugin-dir ./plugins/addison        # load external for one session
claude plugin validate ./plugins/addison     # validate manifest
./build-editions.sh                          # regenerate plugins/addison-internal
./build-zip.sh                               # rebuild dist/addison-plugin.zip for org upload
```

## Release

Bump `version` in `plugins/addison/.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json` (users only receive updates on version bumps), then run `./build-editions.sh`. Update `marketplace.internal.json` to match.

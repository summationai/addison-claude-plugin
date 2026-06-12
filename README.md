# Summation Claude Plugins

Plugin marketplace for Summation. One plugin, `sum`, exposes the public sum-api to Claude surfaces: live OpenAPI discovery, data questions, report generation and export (PDF/DOCX/Markdown).

## Install

**Claude Code (CLI/IDE):**

```
/plugin marketplace add summationai/claude-plugins
/plugin install sum@summationai
```

**claude.ai / Claude Desktop (org admins):** Admin console → Plugins → Add plugins → *Sync from GitHub* (this repo) or *Upload a file* (`dist/sum-plugin.zip`). Members then install from the org library.

> Desktop note: skill scripts run in the code-execution sandbox. The org's code-execution network egress must allow the sum-api host(s) (Capabilities → Code execution), and credentials must be reachable from the sandbox — see the dogfood matrix in the rollout doc.

**Codex:** the `api` skill is tool-agnostic; symlink `plugins/sum/skills/api` into `~/.codex/skills/summation`. (Installer script planned.)

## Contents

| Skill | Invoke | Does |
|---|---|---|
| `start` | `/sum:start` | **guided onboarding**: visual stepper → connect → source map → meet Addison → suggested reports → run one on confirm |
| `api` | model-invoked | OpenAPI-discovery workflow + `scripts/sum_api.py` helper (canonical; sibling skills reference it); first-run source map |
| `login` | `/sum:login` | conversational credential setup → `~/.summation/skill-config` (0600) |
| `doctor` | `/sum:doctor` | connectivity/auth diagnosis + `preflight` environment summary |
| `report` | `/sum:report` | generate a report from a question → export markdown/PDF/DOCX |
| `validate` | `/sum:validate` | run report verification; verdict panel before anything ships externally |
| `query` | `/sum:query` | bounded read-only SQL → rendered table, SQL shown for spot-checking |
| `catalog` | `/sum:catalog` | search/describe tables, views, catalog metadata |

Every API call is audit-logged to `~/.summation/audit.jsonl` (`{ts, method, path, status, duration_ms, request_id, profile}`) — `sum_api.py audit --tail 20` to inspect.

Credentials never live in this repo. `.summation-config*` is ignored and must stay that way.

## Org announcement template

> **Summation is now in Claude.** Open a new chat and type **/sum:start** — it walks you through connecting (2 minutes), shows a map of your data, introduces Addison, and runs your first report. Already connected? Just ask data questions, or use /sum:report, /sum:query, /sum:catalog, /sum:validate.

## For agent harnesses (customer `AGENTS.md` snippet)

Drop this into a repo's `AGENTS.md`/`CLAUDE.md` where agents should prefer Summation:

```md
When working on data analysis, metrics, or report commentary, use the Summation
plugin first (catalog discovery before SQL; never guess table names). Prefer
exported report content over raw internals, cite request_ids on failures, and
run /sum:validate before any report is shared externally. Drafts need explicit
user approval before publishing anywhere.
```

## Dev loop

```bash
claude --plugin-dir ./plugins/sum        # load for one session
claude plugin validate ./plugins/sum     # validate manifest
./build-zip.sh                           # rebuild dist/sum-plugin.zip for org upload
```

## Release

Bump `version` in `plugins/sum/.claude-plugin/plugin.json` AND `.claude-plugin/marketplace.json` (users only receive updates on version bumps).

#!/usr/bin/env bash
# Assemble plugins/codex from the external Addison source of truth.
# plugins/codex is GENERATED. Edit plugins/addison or this builder instead.
set -euo pipefail
cd "$(dirname "$0")"

SRC=plugins/addison
DST=plugins/codex
MARKETPLACE=.agents/plugins/marketplace.json

if find "$SRC" -name ".summation-config*" | grep -q .; then
  echo "refusing to build: credential file inside $SRC" >&2
  exit 1
fi

rm -rf "$DST"
mkdir -p "$(dirname "$DST")" "$(dirname "$MARKETPLACE")"
cp -R "$SRC" "$DST"
rm -rf "$DST/.claude-plugin"
find "$DST" -name "__pycache__" -type d -prune -exec rm -rf {} +

python3 - "$SRC" "$DST" "$MARKETPLACE" <<'PY'
import json
import pathlib
import sys

src = pathlib.Path(sys.argv[1])
dst = pathlib.Path(sys.argv[2])
marketplace_path = pathlib.Path(sys.argv[3])

src_manifest = json.loads((src / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))
version = src_manifest["version"]


def write_json(path: pathlib.Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")


def strip_skill_frontmatter(text: str) -> str:
    if not text.startswith("---\n"):
        return text
    end = text.find("\n---", 4)
    if end == -1:
        return text
    frontmatter = text[4:end].splitlines()
    kept = [
        line
        for line in frontmatter
        if line.startswith("name:") or line.startswith("description:")
    ]
    return "---\n" + "\n".join(kept) + "\n---" + text[end + len("\n---"):]


def codex_text(text: str) -> str:
    replacements = [
        ("/addison:", "$addison-"),
        ("Claude Desktop", "Codex"),
        ("Claude Code", "Codex"),
        ("Claude", "Codex"),
    ]
    for before, after in replacements:
        text = text.replace(before, after)
    return text


for path in dst.rglob("*"):
    if not path.is_file():
        continue
    if path.suffix in {".md", ".html"}:
        text = path.read_text(encoding="utf-8")
        if path.name == "SKILL.md":
            text = strip_skill_frontmatter(text)
        path.write_text(codex_text(text), encoding="utf-8")
    elif path.suffix == ".py":
        text = path.read_text(encoding="utf-8").replace("/addison:", "$addison-")
        path.write_text(text, encoding="utf-8")


login_skill = """---
name: login
description: Verify or reconnect Addison's Codex-managed OAuth session. Use when the user needs to connect Addison or a Summation MCP call reports an authentication error.
---

# Addison Login

Codex owns Addison's MCP registration and OAuth session through the installed plugin. Do not run the local device-login helper, write bearer tokens, or edit Codex config.

## Flow

1. Run `codex mcp remove summation` once to clear any user-level bearer registration left by the pre-OAuth beta. "No MCP server named 'summation' found" is the expected no-op for a clean install; continue to step 2. If Codex reports that it removed the global server, tell the user to start a new thread so the plugin-provided server loads, then stop this run.
2. Call the Summation MCP `whoami` tool.
3. If Codex requests authentication, tell the user to complete the browser sign-in. Retry `whoami` after approval.
4. Report the signed-in identity and organization from the tool result.

If authentication still fails without a browser prompt, ask the user to reconnect Addison from its installed plugin authentication control, then retry `whoami`.

## Rules

- Production only. Do not ask the user to choose an environment or profile.
- Never ask for, print, store, or pass an OAuth token in chat or shell commands.
- Never run `sum_api.py login`, `mcp-connect`, or `mcp-disconnect` for Codex authentication.
"""

logout_skill = """---
name: logout
description: Disconnect Addison's Codex-managed OAuth session. Use when the user wants to sign out or switch Summation accounts.
---

# Addison Logout

Codex owns the OAuth session. Disconnect it with:

```bash
codex mcp logout summation
codex mcp remove summation
```

The remove command clears only a user-level registration left by the pre-OAuth beta; it does not remove the plugin-provided server. "No MCP server named 'summation' found" is a successful no-op.

If Python 3 is available, also run `python3 ../api/scripts/sum_api.py logout` once. This revokes and removes any legacy device-login credential from the beta flow; it is not required for native OAuth logout or for new installations.

Do not edit Codex config directly and do not run `mcp-disconnect`. After logout, a Summation MCP tool call should request authentication again. To switch accounts, disconnect first and then run `$addison-login`.
"""

start_skill = """---
name: start
description: Guided first-run setup for Summation in Codex. Use when a user says "set up Summation", "get started with Summation", asks what Summation can do, or has clearly never connected before.
---

# Summation Start

Codex installs the Summation MCP server with Addison and owns its OAuth session. Do not run local login helpers or edit Codex config.

## Flow

### 1. Connect

Run `codex mcp remove summation` once to clear any user-level bearer registration left by the pre-OAuth beta. A not-found result is the expected no-op for a clean install. If Codex reports that it removed the global server, tell the user to start a new thread so the plugin-provided server loads, then stop this run.

Call `whoami`. If Codex requests authentication, have the user complete the browser sign-in and retry. On success, show the signed-in identity and organization.

### 2. Discover

Use `list_data_connections`, `list_connection_datasets`, `search_tables`, `search_views`, and `list_projects` to build a compact source map from real results.

If there are no data connections, stop and send the user to Summation workspace > Connections. If connections exist but expose no attached datasets, explain that the pipe exists but no business data is analyzable yet, then send the user to the same page to attach datasets. Do not present system tables or merely browsable upstream resources as connected business data.

### 3. Meet Addison

Use `get_default_project`. If no project exists, propose creating `getting-started` and call `create_project` only after the user agrees.

Call `list_catalog_entries`. If the project has no attached data, show a short list from `search_tables`, ask which tables to use, and call `attach_catalog_entry` for the user's selections. Then call `ask_analyst` with this request:

> A new user just connected. In three short bullets, explain what you can do with the data you can see, then propose three specific report ideas grounded in the available tables. Keep it under 120 words.

### 4. First Report

Present the three ideas and ask the user to choose one or describe their own. On confirmation, hand off to `$addison-report`. Offer `$addison-validate` before anything is shared externally.

## Rules

- Use outcomes in user-facing language. Do not narrate tool names, endpoint paths, or schemas.
- Never invent data sources, tables, projects, or metrics. Mirror MCP results.
- Keep the truth ladder explicit: connection, attached dataset, project catalog entry, analyzable by Addison.
- If a tool fails, report its request id when available and preserve the user's place in the flow.
"""

doctor_skill = """---
name: doctor
description: Diagnose Addison MCP connectivity and OAuth in Codex. Use when Summation calls fail, authentication seems stale, or the user asks whether Addison is connected correctly.
---

# Summation Doctor

Codex owns the Summation MCP server and OAuth session. Do not inspect or edit Codex config, and do not run the local device-login helper.

1. Call `whoami`.
2. If Codex requests authentication, have the user complete browser sign-in and retry.
3. If identity succeeds, call `get_default_project` and `list_data_connections` to distinguish an auth problem from an empty workspace.
4. Report the signed-in identity, organization, default project, and connection count. Include a request id on failure when available.

If authentication still fails without a browser prompt, hand off to `$addison-login` for the native reconnect flow.
"""

(dst / "skills" / "login" / "SKILL.md").write_text(login_skill, encoding="utf-8")
(dst / "skills" / "logout" / "SKILL.md").write_text(logout_skill, encoding="utf-8")
(dst / "skills" / "start" / "SKILL.md").write_text(start_skill, encoding="utf-8")
(dst / "skills" / "doctor" / "SKILL.md").write_text(doctor_skill, encoding="utf-8")

api_path = dst / "skills" / "api" / "SKILL.md"
api_text = api_path.read_text(encoding="utf-8")
api_replacements = [
    (
        "**MCP-first:** when the `summation` MCP server is connected, prefer its tools for all data operations (see \"MCP Relationship\" below). Use this script as the fallback when the server is not connected, and always for auth plumbing (`login`, `login-poll`, `logout`, `mcp-connect`, `doctor`).",
        "**MCP-first:** prefer the `summation` MCP tools for normal Codex work. Codex owns the plugin's MCP registration and OAuth session. Use this script only as an explicit REST fallback when a separate local sum-api credential already exists; never use it for Codex MCP authentication.",
    ),
    (
        "3. Authenticate with the stored device-login credential only.",
        "3. For REST fallback only, authenticate with a separately stored device-login credential.",
    ),
    (
        "- `mcp-connect` — register the hosted Summation MCP server with Codex using the stored credential (run after login; credential moves process-to-process, never through chat).\n- `mcp-disconnect` — remove that MCP registration (run on logout).\n",
        "",
    ),
    (
        "For interactive user login, use the sibling `login` skill. It owns the device-login flow, what to show the user, polling behavior, MCP registration, and logout guidance. If no credential is stored, the helper exits with \"Not signed in to Summation. Run $addison-login to connect.\" — do that, don't improvise auth.",
        "The sibling `login` skill owns native Codex MCP authentication. A local device-login credential is optional and applies only to direct REST fallback calls. Never copy an MCP OAuth token into this helper or use `mcp-connect` from Codex.",
    ),
    (
        "The hosted Summation MCP server (`summation`, `https://mcp.summation.com/mcp`) exposes 41 curated, non-destructive tools over the same public API: multi-turn analyst (`ask_analyst` → `reply_to_analyst` with context), identity/project bootstrap (`whoami`, `get_default_project`, `create_project`), source discovery (connections/datasets), tables/views/query with previews and lineage, files (upload/download/import), reports, playbooks, and schedules. `$addison-login` registers it via `mcp-connect`.",
        "The hosted Summation MCP server (`summation`, `https://mcp.summation.com/mcp`) exposes 41 curated, non-destructive tools over the same public API: multi-turn analyst (`ask_analyst` → `reply_to_analyst` with context), identity/project bootstrap (`whoami`, `get_default_project`, `create_project`), source discovery (connections/datasets), tables/views/query with previews and lineage, files (upload/download/import), reports, playbooks, and schedules. The plugin manifest registers it and Codex manages OAuth.",
    ),
    (
        "Fall back to the script when the server is not connected; auth plumbing always goes through the script.",
        "Use the script only for a deliberate REST fallback with its own local credential. MCP authentication never goes through the script in Codex.",
    ),
    (
        "- **Auth errors mean a revoked/expired bearer**: re-run `$addison-login` (it mints a fresh credential and re-registers the server).",
        "- **Auth errors**: run `$addison-login`; Codex handles browser OAuth and retries the MCP connection.",
    ),
]
for before, after in api_replacements:
    if before not in api_text:
        raise SystemExit(f"Codex API overlay anchor not found: {before[:80]}")
    api_text = api_text.replace(before, after)
api_path.write_text(api_text, encoding="utf-8")

auth_path = dst / "skills" / "api" / "references" / "auth.md"
auth_text = auth_path.read_text(encoding="utf-8")
auth_replacements = [
    (
        "Use the sibling `login` skill for the step-by-step interactive flow. The helper starts login with `login`, stores temporary local polling state (`0600`), completes approval with `login-poll`, registers the hosted MCP server with `mcp-connect`, and revokes the device-login session plus removes the local credential with `logout` (pair with `mcp-disconnect`).",
        "The helper's device-login flow is only for direct REST fallback. The sibling `login` skill handles Codex MCP authentication natively; never use `mcp-connect` or `mcp-disconnect` for Codex.",
    ),
    (
        "`mcp-connect` registers `https://mcp.summation.com/mcp` with Codex (user scope), passing the stored credential as a bearer header via subprocess argv — never through chat, stdout, or a shell string. `mcp-disconnect` removes the registration. A revoked/expired credential surfaces as MCP auth errors; re-run the login flow to fix.",
        "The plugin's `.mcp.json` registers `https://mcp.summation.com/mcp`, and Codex owns the OAuth session. Do not place MCP tokens in local config or pass them to this helper. Use `$addison-login` when native MCP authentication needs to be renewed.",
    ),
]
for before, after in auth_replacements:
    if before not in auth_text:
        raise SystemExit(f"Codex auth overlay anchor not found: {before[:80]}")
    auth_text = auth_text.replace(before, after)
auth_path.write_text(auth_text, encoding="utf-8")

plugin_json = {
    "name": "addison",
    "version": version,
    "description": "Addison, Summation's AI data analyst, in Codex: ask data questions, search the catalog, run bounded SQL, generate and validate reports, and export artifacts.",
    "author": {
        "name": "Summation",
        "url": "https://summation.com",
    },
    "homepage": "https://summation.com",
    "repository": src_manifest["repository"],
    "license": src_manifest.get("license", "MIT"),
    "keywords": sorted(set(src_manifest.get("keywords", []) + ["codex", "mcp"])),
    "skills": "./skills/",
    "mcpServers": "./.mcp.json",
    "interface": {
        "displayName": "Addison",
        "shortDescription": "Ask Addison data questions from Codex.",
        "longDescription": "Addison brings Summation's AI data analyst into Codex for governed data questions, catalog discovery, SQL, reports, validation, and scheduling. Codex connects to the hosted Summation MCP server and manages browser OAuth natively.",
        "developerName": "Summation",
        "category": "Data",
        "capabilities": ["Interactive", "Data analysis", "Reports", "MCP"],
        "websiteURL": "https://summation.com",
        "brandColor": "#2F6FEB",
        "defaultPrompt": [
            "Set up Addison for Summation.",
            "What data can Addison see?",
            "Generate a report from my data."
        ],
    },
}
write_json(dst / ".mcp.json", {
    "mcpServers": {
        "summation": {
            "type": "http",
            "url": "https://mcp.summation.com/mcp",
            "oauth_resource": "https://mcp.summation.com",
        },
    },
})
write_json(dst / ".codex-plugin" / "plugin.json", plugin_json)

entry = {
    "name": "addison",
    "source": {
        "source": "local",
        "path": "./plugins/codex",
    },
    "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL",
    },
    "category": "Data",
}
if marketplace_path.exists():
    marketplace = json.loads(marketplace_path.read_text(encoding="utf-8"))
else:
    marketplace = {
        "name": "summation",
        "interface": {
            "displayName": "Summation",
        },
        "plugins": [],
    }

marketplace.setdefault("name", "summation")
marketplace.setdefault("interface", {"displayName": "Summation"})
plugins = marketplace.setdefault("plugins", [])
for index, existing in enumerate(plugins):
    if isinstance(existing, dict) and existing.get("name") == entry["name"]:
        plugins[index] = entry
        break
else:
    plugins.append(entry)
write_json(marketplace_path, marketplace)
PY

VERSION=$(python3 -c "import json; print(json.load(open('$DST/.codex-plugin/plugin.json'))['version'])")
echo "built $DST (version $VERSION)"

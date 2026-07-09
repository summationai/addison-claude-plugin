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
description: Sign in to Summation. Use when the user needs to connect Addison, fix credentials, or when any Summation call fails with 401/403 and no valid config exists.
---

# Addison Login

One browser sign-in connects everything: the sum-api credential and the hosted Summation MCP server. The helper lives in the sibling `api` skill: `../api/scripts/sum_api.py`.

There is exactly one environment: production. Do not ask the user to choose an environment or a profile.

## Flow

1. Start device login:

```bash
python3 ../api/scripts/sum_api.py login --surface codex
```

2. Present only the returned `verification_uri_complete` and `user_code` to the user:

> Open this link and approve to connect Codex to Summation — it expires in 10 minutes.
> **<verification_uri_complete>**
> Verification code: **<user_code>**
>
> You'll approve in your browser; no password or secret is shared in this chat.

Do not print or quote `device_code`, and do not paste raw helper JSON containing internal polling state into chat.

3. Poll immediately until the login reaches a terminal state:

```bash
python3 ../api/scripts/sum_api.py login-poll
```

Terminal outcomes:

- `{"status":"approved", ...}`: approval succeeded. The helper stored `SUM_API_DEVICE_LOGIN_CREDENTIAL` in `~/.summation/config` with file mode `0600`. Continue.
- `{"status":"denied"}`: the user rejected the browser approval. No credential was stored. Offer to start over.
- `{"status":"expired"}`: the approval link expired. No credential was stored. Offer to start over.

4. Connect the Summation MCP server to Codex:

```bash
python3 ../api/scripts/sum_api.py mcp-connect --client codex
```

This writes the hosted MCP server (`https://mcp.summation.com/mcp`) into `~/.codex/config.toml` with the stored credential as a bearer header. The config file is written with mode `0600`, and the credential must never appear in chat. Tell the user to start a new Codex thread or restart Codex to load the Summation tools.

5. Verify:

```bash
python3 ../api/scripts/sum_api.py doctor
python3 ../api/scripts/sum_api.py call GET /v1/me
```

6. Report the signed-in identity, whether the MCP server was registered, and `request_id` on any failure.

## Logout

Revoke the device-login session, remove the local credential, and deregister the MCP server:

```bash
python3 ../api/scripts/sum_api.py logout
python3 ../api/scripts/sum_api.py mcp-disconnect --client codex
```

Always run both commands. `mcp-disconnect --client codex` removes the bearer header from Codex config.

## Rules

- Production only; there is no environment or profile selection. If the user asks about sandbox/staging environments, explain those are available in Summation's internal edition.
- Never print, log, or commit the device-login credential or any token.
- The helper stores temporary polling state locally after `login`; do not surface `device_code`, `interval`, or `expires_in` in chat.
- If a Summation MCP call later fails with an auth error, the stored bearer has likely been revoked or expired: re-run this login flow to mint a fresh credential and re-register the MCP server.
"""

logout_skill = """---
name: logout
description: Disconnect Codex from Summation, revoke the stored device-login session, remove the local credential, and deregister the Summation MCP server. Use when the user wants to disconnect, sign in as a different Summation user, or clear a stale session.
---

# Addison Logout

Revoke the stored device-login session, remove `SUM_API_DEVICE_LOGIN_CREDENTIAL`, and deregister the Summation MCP server from Codex. The helper lives in the sibling `api` skill: `../api/scripts/sum_api.py`.

## Flow

1. Run logout, then deregister the MCP server:

```bash
python3 ../api/scripts/sum_api.py logout
python3 ../api/scripts/sum_api.py mcp-disconnect --client codex
```

2. Interpret the results:

- `logout` -> `{"status":"logged_out", ...}` means the device-login session was revoked and the credential removed. `{"status":"already_logged_out", ...}` means no credential was present.
- `mcp-disconnect --client codex` -> `{"status":"disconnected"}` means the MCP registration was removed from Codex config. `{"status":"not_registered"}` means nothing was present.

## Rules

- Always run both commands: a revoked session must not leave a stale bearer header in Codex config.
- Report both outcomes to the user.
"""

(dst / "skills" / "login" / "SKILL.md").write_text(login_skill, encoding="utf-8")
(dst / "skills" / "logout" / "SKILL.md").write_text(logout_skill, encoding="utf-8")

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
    "interface": {
        "displayName": "Addison",
        "shortDescription": "Ask Addison data questions from Codex.",
        "longDescription": "Addison brings Summation's AI data analyst into Codex for governed data questions, catalog discovery, SQL, reports, validation, and scheduling. One browser approval stores a local credential and connects the hosted Summation MCP server.",
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
write_json(dst / ".codex-plugin" / "plugin.json", plugin_json)

entry = {
    "name": "addison",
    "source": {
        "source": "local",
        "path": "./plugins/codex",
    },
    "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_USE",
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

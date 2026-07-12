---
name: signout
description: Disconnect Codex from Summation — revoke the stored device-login session, remove the local credential, and deregister the Summation MCP server. Use to disconnect, sign in as a different Summation user, or clear a stale session.
---

# Addison Sign-out

Revoke the stored device-login session, remove `SUM_API_DEVICE_LOGIN_CREDENTIAL`, and deregister the Summation MCP server from Codex. The helper lives in the sibling `api` skill: `../api/scripts/sum_api.py`.

## Flow

1. Revoke the session, then deregister the server:

```bash
python3 ../api/scripts/sum_api.py logout
python3 ../api/scripts/sum_api.py mcp-disconnect --client codex
```

2. Interpret the results:

- `logout` -> `{"status":"logged_out", ...}` — the session was revoked and the credential removed. `{"status":"already_logged_out", ...}` — nothing was present.
- `mcp-disconnect --client codex` -> `{"status":"disconnected"}` — the server block (and its bearer header) was removed from `~/.codex/config.toml`. `{"status":"not_registered"}` — nothing was present.

## Rules

- Always run both: a revoked session must not leave a stale bearer header in Codex config.
- Report both outcomes to the user.

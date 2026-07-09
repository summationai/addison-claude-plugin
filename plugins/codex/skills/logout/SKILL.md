---
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

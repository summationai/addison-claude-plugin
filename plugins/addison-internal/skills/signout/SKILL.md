---
name: signout
description: Revoke the stored Summation device-login session and remove only `SUM_API_DEVICE_LOGIN_CREDENTIAL` from the active or selected profile. Use when the user wants to disconnect Claude from Summation, sign in again as a different Summation user, or clear a stale device-login session.
---

# Summation Logout

Revoke the stored device-login session and then remove only `SUM_API_DEVICE_LOGIN_CREDENTIAL` without touching M2M settings. The helper lives in the sibling `api` skill: `<plugin>/skills/api/scripts/sum_api.py` (resolve relative to this skill's base directory: `../api/scripts/sum_api.py`).

## Flow

1. Resolve the target profile:
   - If the user names a profile, use it.
   - Otherwise use the active profile by default.
2. Run logout:

```bash
python3 ../api/scripts/sum_api.py logout [--profile <NAME>]
```

3. Interpret the result:
   - `{"status":"logged_out", ...}` — the device-login session was revoked and only `SUM_API_DEVICE_LOGIN_CREDENTIAL` was removed.
   - `{"status":"already_logged_out", ...}` — no device-login credential was present for that profile.

## Rules

- Logout revokes the device-login session before removing `SUM_API_DEVICE_LOGIN_CREDENTIAL`.
- Never remove M2M settings as part of logout.
- Report the affected profile.

## MCP deregistration

After logout, also run `python3 ../api/scripts/sum_api.py mcp-disconnect` — it removes the Claude Code MCP registration that carries a bearer header from `mcp-connect`.

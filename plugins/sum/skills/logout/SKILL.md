---
name: logout
description: Remove the stored Summation device-login credential from the active or selected profile. Use when the user wants to disconnect Claude from Summation, switch accounts, or clear a stale device-login session.
---

# Summation Logout

Remove the locally stored device-login credential without touching M2M settings. The helper lives in the sibling `api` skill: `<plugin>/skills/api/scripts/sum_api.py` (resolve relative to this skill's base directory: `../api/scripts/sum_api.py`).

## Flow

1. Resolve the target profile:
   - If the user names a profile, use it.
   - Otherwise use the active profile by default.
2. Run logout:

```bash
python3 ../api/scripts/sum_api.py logout [--profile <NAME>]
```

3. Interpret the result:
   - `{"status":"logged_out", ...}` — the device-login credential was removed.
   - `{"status":"already_logged_out", ...}` — no device-login credential was present for that profile.

## Rules

- Logout removes only `SUM_API_DEVICE_LOGIN_CREDENTIAL`.
- Never remove M2M settings as part of logout.
- Report the config file path and profile that were affected.

---
name: login
description: Authenticate with Summation (sum-api). Use when the user needs to set up, fix, or switch Summation credentials or profiles, or when any Summation call fails with 401/403 and no valid config exists.
---

# Summation Login

Set up sum-api credentials through device login by default. The helper lives in the sibling `api` skill: `<plugin>/skills/api/scripts/sum_api.py` (resolve relative to this skill's base directory: `../api/scripts/sum_api.py`).

## Flow

1. Ask the user for: base URL (default `https://sandbox-api.summation.com`) and an optional profile name.
2. Start device login:

```bash
python3 ../api/scripts/sum_api.py login --base-url <BASE_URL> [--profile <NAME>] [--surface claude-code|claude-desktop]
```

3. Present the returned `verification_uri_complete` and `user_code` to the user. Tell them to open the link themselves; do not open it for them. Use this shape:

   > Open this link and approve to connect Claude to Summation — it expires in 10 minutes.
   > **<verification_uri_complete>**
   > Verification code: **<user_code>**
   >
   > You'll approve in your browser; no password or secret is shared in this chat.

   Show only `verification_uri_complete` and `user_code` to the user. Do not print or quote
   `device_code`, and do not paste raw helper JSON into chat. Do not ask the user to share
   passwords, session tokens, client secrets, or other credentials in chat.
4. Poll until the login reaches a terminal state:

```bash
python3 ../api/scripts/sum_api.py login-poll \
  --base-url <BASE_URL> \
  --device-code <DEVICE_CODE> \
  --interval <INTERVAL> \
  --expires-in <EXPIRES_IN> \
  [--profile <NAME>]
```

   On success this stores `SUM_API_DEVICE_LOGIN_CREDENTIAL` in `~/.summation/skill-config` with file mode `0600`.

   Treat `login-poll` as the terminal step in the flow. It should normally return one of these outcomes:
   - `{"status":"approved", ...}`: approval succeeded. The helper already stored `SUM_API_DEVICE_LOGIN_CREDENTIAL` locally in `~/.summation/skill-config` (file mode `0600`). Continue to verification.
   - `{"status":"denied"}`: the user rejected the request in the browser. No credential was stored. Offer to start over with a fresh `login` flow.
   - `{"status":"expired"}`: the approval link expired. No credential was stored. Offer to start over with a fresh `login` flow.

   `pending` is not a normal terminal outcome for the agent to present. The helper keeps polling internally until it reaches `approved`, `denied`, or `expired`.

5. Verify immediately:

```bash
python3 ../api/scripts/sum_api.py doctor
python3 ../api/scripts/sum_api.py call GET /v1/projects
```

6. Report: config path, active profile, and whether the authenticated list call succeeded (include `request_id` on failure).

## Logout

Remove the locally stored device-login credential without touching any M2M settings:

```bash
python3 ../api/scripts/sum_api.py logout [--profile <NAME>]
```

## M2M Fallback

If device login is unavailable and the user already has machine credentials, fall back to M2M configuration:

```bash
python3 ../api/scripts/sum_api.py configure \
  --base-url <BASE_URL> --client-id <CLIENT_ID> --client-secret <CLIENT_SECRET> \
  [--profile <NAME> --activate]
```

If the user has no `client_id`/`client_secret` and specifically needs M2M credentials, explain that API credentials are issued by their Summation admin (or Summation support), then offer to draft the request for them:

> Subject: Summation API credentials for Claude
> Hi — I'm connecting Claude to Summation and need machine credentials: the API **base URL** for our tenant, a **client_id** and **client_secret** with scopes `agent:read agent:write`. Please share them securely (not over chat/email plaintext).

Tell them to come back with `/sum:login` once they have the three values — and that the values are stored locally with file mode 0600, never in this conversation's history beyond their one paste.

## Rules

- Prefer device login over M2M whenever both are viable.
- Never print, log, or commit the device-login credential, access token, or client secret.
- Multiple environments → named profiles (`--profile`), switch with `use-profile <name>`.
- Carry `device_code`, `interval`, and `expires_in` forward from `login` into `login-poll`; they are part of the device-login contract.
- If `configure` is needed for M2M fallback, pass all values as flags.

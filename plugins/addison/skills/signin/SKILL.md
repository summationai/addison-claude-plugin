---
name: signin
description: Sign in to Summation. Use when the user needs to connect Addison, fix credentials, or when any Summation call fails with 401/403 and no valid config exists.
---

# Addison Login

One browser sign-in connects everything: the sum-api credential AND the hosted Summation MCP server (41 data tools). The helper lives in the sibling `api` skill: `<plugin>/skills/api/scripts/sum_api.py` (resolve relative to this skill's base directory: `../api/scripts/sum_api.py`).

There is exactly one environment (production). Do not ask the user to choose an environment or a profile — start the flow immediately.

## Flow

1. Start device login:

```bash
python3 ../api/scripts/sum_api.py login --surface <claude-code|claude-desktop>
```

   Always pass `--surface`. Use `claude-desktop` when running in Claude Desktop and
   `claude-code` when running in Claude Code. Do not rely on a helper default.

2. Present the returned `verification_uri_complete` and `user_code` to the user. Tell them to open the link themselves; do not open it for them. Use this shape:

   > Open this link and approve to connect Claude to Summation — it expires in 10 minutes.
   > **<verification_uri_complete>**
   > Verification code: **<user_code>**
   >
   > You'll approve in your browser; no password or secret is shared in this chat.

   Show only `verification_uri_complete` and `user_code` to the user. Do not print or quote
   `device_code`, and do not paste raw helper JSON containing internal polling state into chat. Do not ask the user to share
   passwords, session tokens, client secrets, or other credentials in chat.

3. Poll until the login reaches a terminal state:

```bash
python3 ../api/scripts/sum_api.py login-poll
```

   Start `login-poll` immediately after presenting the approval link. The user completes
   approval in their browser, not in chat, so do not pause the flow waiting for a chat
   reply before starting the poll step.

   Terminal outcomes:
   - `{"status":"approved", ...}`: approval succeeded. The helper stored `SUM_API_DEVICE_LOGIN_CREDENTIAL` in `~/.summation/summation-config` (file mode `0600`). Continue.
   - `{"status":"denied"}`: the user rejected the request in the browser. No credential was stored. Offer to start over.
   - `{"status":"expired"}`: the approval link expired. No credential was stored. Offer to start over.

4. Connect the Summation MCP server (Claude Code only; skip on Claude Desktop):

```bash
python3 ../api/scripts/sum_api.py mcp-connect
```

   This registers the hosted MCP server (`https://mcp.summation.com/mcp`) in the user's
   Claude Code config with the stored credential as a bearer header. The credential is passed
   process-to-process and never appears in chat. Tell the user to restart Claude Code (or run
   `/mcp`) to load the Summation tools.

5. Verify:

```bash
python3 ../api/scripts/sum_api.py doctor
python3 ../api/scripts/sum_api.py call GET /v1/me
```

6. Report: signed-in identity, whether the MCP server was registered, and `request_id` on any failure.

## Logout

Revoke the device-login session, remove the local credential, and deregister the MCP server:

```bash
python3 ../api/scripts/sum_api.py logout
python3 ../api/scripts/sum_api.py mcp-disconnect
```

Always run both — `mcp-disconnect` removes the bearer header that `mcp-connect` stored in the Claude Code MCP registration.

## Rules

- Production only; there is no environment or profile selection. If the user asks about sandbox/staging environments, explain those are available in Summation's internal edition.
- Never print, log, or commit the device-login credential or any token.
- The helper stores temporary polling state locally after `login`; do not surface `device_code`, `interval`, or `expires_in` in chat.
- If a Summation MCP call later fails with an auth error, the stored bearer has likely been revoked or expired: re-run this login flow (steps 1-4) to mint a fresh credential and re-register the MCP server.

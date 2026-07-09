---
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

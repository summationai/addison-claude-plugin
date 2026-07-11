---
name: signin
description: Sign in to Summation from Codex. Use when the user needs to connect Addison, fix credentials, or when any Summation call fails with 401/403 and no valid session exists.
---

# Addison Sign-in

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

- `{"status":"approved", ...}`: approval succeeded. The helper stored `SUM_API_DEVICE_LOGIN_CREDENTIAL` in `~/.summation/summation-config` (mode `0600`). Continue.
- `{"status":"denied"}`: the user rejected the browser approval. No credential was stored. Offer to start over.
- `{"status":"expired"}`: the approval link expired. No credential was stored. Offer to start over.

4. Register the Summation MCP server with Codex:

```bash
python3 ../api/scripts/sum_api.py mcp-connect --client codex
```

This writes the hosted MCP server (`https://mcp.summation.com/mcp`) into `~/.codex/config.toml` with the stored credential as a bearer header (mode `0600`). The credential moves process-to-process and must never appear in chat. Tell the user to start a new Codex thread (or restart Codex) to load the Summation tools.

5. Verify:

```bash
python3 ../api/scripts/sum_api.py doctor
python3 ../api/scripts/sum_api.py call GET /v1/me
```

6. Report the signed-in identity, whether the MCP server was registered, and `request_id` on any failure.

## Rules

- Production only; there is no environment or profile selection. Sandbox/staging is a Summation internal-edition capability.
- Never print, log, or commit the device-login credential or any token.
- The helper stores temporary polling state locally after `login`; do not surface `device_code`, `interval`, or `expires_in` in chat.
- If a Summation MCP call later fails with an auth error, the stored bearer was likely revoked or expired: re-run this sign-in flow to mint a fresh credential and re-register the server.

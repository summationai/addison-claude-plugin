---
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

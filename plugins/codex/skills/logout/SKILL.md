---
name: logout
description: Disconnect Addison's Codex-managed OAuth session. Use when the user wants to sign out or switch Summation accounts.
---

# Addison Logout

Codex owns the OAuth session. Disconnect it with:

```bash
codex mcp logout summation
codex mcp remove summation
```

The remove command clears only a user-level registration left by the pre-OAuth beta; it does not remove the plugin-provided server. "No MCP server named 'summation' found" is a successful no-op.

If Python 3 is available, also run `python3 ../api/scripts/sum_api.py logout` once. This revokes and removes any legacy device-login credential from the beta flow; it is not required for native OAuth logout or for new installations.

Do not edit Codex config directly and do not run `mcp-disconnect`. After logout, a Summation MCP tool call should request authentication again. To switch accounts, disconnect first and then run `$addison-login`.

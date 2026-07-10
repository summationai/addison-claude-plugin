---
name: doctor
description: Diagnose Addison MCP connectivity and OAuth in Codex. Use when Summation calls fail, authentication seems stale, or the user asks whether Addison is connected correctly.
---

# Summation Doctor

Codex owns the Summation MCP server and OAuth session. Do not inspect or edit Codex config, and do not run the local device-login helper.

1. Call `whoami`.
2. If Codex requests authentication, have the user complete browser sign-in and retry.
3. If identity succeeds, call `get_default_project` and `list_data_connections` to distinguish an auth problem from an empty workspace.
4. Report the signed-in identity, organization, default project, and connection count. Include a request id on failure when available.

If authentication still fails without a browser prompt, hand off to `$addison-login` for the native reconnect flow.

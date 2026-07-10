---
name: start
description: Guided first-run setup for Summation in Codex. Use when a user says "set up Summation", "get started with Summation", asks what Summation can do, or has clearly never connected before.
---

# Summation Start

Codex installs the Summation MCP server with Addison and owns its OAuth session. Do not run local login helpers or edit Codex config.

## Flow

### 1. Connect

Run `codex mcp remove summation` once to clear any user-level bearer registration left by the pre-OAuth beta. A not-found result is the expected no-op for a clean install. If Codex reports that it removed the global server, tell the user to start a new thread so the plugin-provided server loads, then stop this run.

Call `whoami`. If Codex requests authentication, have the user complete the browser sign-in and retry. On success, show the signed-in identity and organization.

### 2. Discover

Use `list_data_connections`, `list_connection_datasets`, `search_tables`, `search_views`, and `list_projects` to build a compact source map from real results.

If there are no data connections, stop and send the user to Summation workspace > Connections. If connections exist but expose no attached datasets, explain that the pipe exists but no business data is analyzable yet, then send the user to the same page to attach datasets. Do not present system tables or merely browsable upstream resources as connected business data.

### 3. Meet Addison

Use `get_default_project`. If no project exists, propose creating `getting-started` and call `create_project` only after the user agrees.

Call `list_catalog_entries`. If the project has no attached data, show a short list from `search_tables`, ask which tables to use, and call `attach_catalog_entry` for the user's selections. Then call `ask_analyst` with this request:

> A new user just connected. In three short bullets, explain what you can do with the data you can see, then propose three specific report ideas grounded in the available tables. Keep it under 120 words.

### 4. First Report

Present the three ideas and ask the user to choose one or describe their own. On confirmation, hand off to `$addison-report`. Offer `$addison-validate` before anything is shared externally.

## Rules

- Use outcomes in user-facing language. Do not narrate tool names, endpoint paths, or schemas.
- Never invent data sources, tables, projects, or metrics. Mirror MCP results.
- Keep the truth ladder explicit: connection, attached dataset, project catalog entry, analyzable by Addison.
- If a tool fails, report its request id when available and preserve the user's place in the flow.

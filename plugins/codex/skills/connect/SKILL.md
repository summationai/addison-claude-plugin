---
name: connect
description: Connect a data source (Postgres, Snowflake, etc.) to Summation from this conversation — collects non-secret settings in chat, takes the secret through a local file so it never enters the conversation, then creates and tests the connection. Use when the user wants to add, fix, or test a data connection.
---

# Summation Connect

Create a data connection via `POST /v1/connections` (`{name, type, config, secrets, description}` — secrets are stored server-side as secret refs). Helper: `../api/scripts/sum_api.py`. Always `describe create_connection` first for the current type-specific config shape.

Connection **creation stays on the REST path** even when the `summation` MCP server is connected — the secret must travel via the local-file handoff below, never through a tool argument that lands in the transcript. Browsing/inspecting sources afterwards can use the MCP source-discovery tools.

## The secret rule (read first)

**Never ask for a password/secret in chat.** Offer the paths in this order:

- **File handoff (default in-flow path — Codex, Cowork, any surface with a user filesystem):** the secret goes into a local file the user creates in their own terminal; it never appears in the conversation, argv, or transcripts. The connection is created in ONE call with config + secrets together.
- **Webapp end-to-end (default on Desktop chat, where there is no user filesystem):** workspace → Connections → Add connection. Offer to dictate the exact non-secret values to enter so the user only has to type and not think.
- **Pasted-secret salvage (the user already pasted it):** do NOT refuse and bounce them — the exposure already happened, and retyping punishes intent. Proceed: create the connection with the pasted secret (TLS to sum-api, stored as a secret ref), then firmly advise rotating that credential at the source since it transited chat history. Teach the file handoff for next time.

**Never create a connection without its secrets.** The API accepts a secretless `create_connection`, but the product cannot complete it — a connection cannot be saved/finished in the webapp without its password, so a secretless create strands an orphan the user cannot fix. Create only when the secret is in hand (file or salvage); if an orphan ever gets created, delete it (`DELETE /v1/connections/<id>?confirm=true`).

## Flow

1. Collect **non-secret** settings in chat: type, a connection name, and the type-specific config (host/account, port, database/warehouse, user, …) per the described schema. Echo them back for a yes before anything is created.
2. Secret via file handoff, then create in one call:

```bash
# user runs (or you instruct them precisely):
#   mkdir -p ~/.summation && printf '%s' 'THE_SECRET' > ~/.summation/pending-secret && chmod 600 ~/.summation/pending-secret
# then you assemble the body WITHOUT echoing the secret:
python3 -c "
import json, pathlib
secret = pathlib.Path.home().joinpath('.summation/pending-secret').read_text().strip()
body = {'name': '<NAME>', 'type': '<TYPE>', 'config': {<NON_SECRET_CONFIG>}, 'secrets': {'<SECRET_KEY>': secret}}
out = pathlib.Path.home().joinpath('.summation/pending-connection.json')
out.write_text(json.dumps(body)); out.chmod(0o600)
"
python3 ../api/scripts/sum_api.py call POST /v1/connections --body-file ~/.summation/pending-connection.json
rm -f ~/.summation/pending-secret ~/.summation/pending-connection.json
```

3. **Always clean up the temp files immediately** (the `rm -f`), success or failure.
4. **Test it**: `call POST /v1/connections/<NEW_ID>/tests` — report pass/fail with `request_id`. Optionally `call POST /v1/connections/<NEW_ID>/resources` to show what's now browsable.
5. **A live connection is not the finish line — datasets are.** After the test passes, check the connection's `datasetCount` (visible in `call GET /v1/connections`). If 0: browse what's attachable (`call POST /v1/connections/<ID>/resources --body '{"max_results": 200}'`), show the tree as a preview, and send the user to the connection's page in workspace → **Connections** to attach the datasets they want analyzed (no public API for attachment yet). Only after `preflight` shows `connections.datasets_total > 0` is the data usable.
6. Hand back: if this ran inside `$addison-start`, return to its Step 2 gate (re-run `preflight` — both gates should now pass).

## Rules

- **User-facing voice**: narrate outcomes, never endpoints, schemas, or capability doubts — API discovery is silent. Dataset attachment is KNOWN webapp-only (`/v1/table-imports` is CSV/file upload, not connection attachment — never offer it for this); don't re-verify in conversation.
- Secret values never appear in: chat messages you write, command argv, logs, or the audit trail (the helper never logs bodies).
- Echo back everything EXCEPT secrets before creating (name, type, config) and get a yes — creating a connection is a tenant-level change.
- On create/test failure, surface the `request_id` and the non-secret config for debugging; never print the secret or ask the user to re-paste it into chat.

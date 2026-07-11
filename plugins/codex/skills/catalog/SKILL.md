---
name: catalog
description: Search and describe Summation tables, views, and catalog metadata. Use when the user asks what data exists, wants schemas or column details, or before writing any SQL.
---

# Summation Catalog

Discover what data exists before touching it.

**MCP-first**: when the `summation` MCP server is connected, use its source-discovery and table/view tools (search, describe, previews, lineage) instead of the REST calls below. Caveat: `get_view`/`preview_view_data` can 404 on ids from `search_views` (known bug) — fall back to the tables path. Helper fallback: `../api/scripts/sum_api.py`. The `/v1/...` paths below are illustrative — if a call returns 404, the route may have moved — rediscover via `operations`/`operation` (the contract is the source of truth).

## Flow

1. **Inventory**: `call GET /v1/tables` and `call GET /v1/views` (paginated — note `total` vs shown). Filter client-side by the user's search term across names.
2. **Detail**: for a specific table/view:
   - `call GET /v1/tables/<TABLE_ID>` — definition
   - `call GET /v1/tables/<TABLE_ID>/catalog` — catalog metadata (descriptions, semantics)
   - `call GET /v1/tables/<TABLE_ID>/data --query '{"limit": 5}'` — peek at sample rows (small limits only)
3. Render compact schema cards: name, id, column names/types if available, one-line description. Group tables vs views.

## Rules

- With 500+ tables, never dump the full list — show matches plus the total count, and ask to narrow.
- Sample-row peeks stay at `limit ≤ 5`; this is discovery, not analysis (`$addison-query` is for that).
- Suggest next steps: a `$addison-query` against a found table, or `$addison-report` for a full analysis.

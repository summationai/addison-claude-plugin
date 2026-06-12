---
name: catalog
description: Search and describe Summation tables, views, and catalog metadata. Use when the user asks what data exists, wants schemas or column details, or before writing any SQL.
argument-hint: [search term]
---

# Summation Catalog

Discover what data exists before touching it. Helper: `../api/scripts/sum_api.py`.

## Flow

1. **Inventory**: `call GET /v1/tables` and `call GET /v1/views` (paginated — note `total` vs shown). Filter client-side by the user's search term across names.
2. **Detail**: for a specific table/view:
   - `call GET /v1/tables/<TABLE_ID>` — definition
   - `call GET /v1/tables/<TABLE_ID>/catalog` — catalog metadata (descriptions, semantics)
   - `call GET /v1/tables/<TABLE_ID>/data --query '{"limit": 5}'` — peek at sample rows (small limits only)
3. Render compact schema cards: name, id, column names/types if available, one-line description. Group tables vs views.

## Rules

- With 500+ tables, never dump the full list — show matches plus the total count, and ask to narrow.
- Sample-row peeks stay at `limit ≤ 5`; this is discovery, not analysis (`/sum:query` is for that).
- Suggest next steps: a `/sum:query` against a found table, or `/sum:report` for a full analysis.

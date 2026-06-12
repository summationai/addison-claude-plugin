---
name: start
description: Summation onboarding wizard — guided first-run setup with a visual progress stepper, credential setup, data source map, a hello from Addison, and suggested first reports. Use when a user says "set up summation", "get started with summation", asks what Summation can do, or has clearly never connected before.
---

# Summation Start — five-star onboarding

Walk a brand-new user from zero to their first report, with a visual that tracks progress. Helper: `../api/scripts/sum_api.py`.

## The four steps

```
1 CONNECT → 2 DISCOVER → 3 MEET ADDISON → 4 FIRST REPORT
```

**Render the welcome visual FIRST, before any API call** — an interactive HTML visual (artifact) titled "Welcome to Summation", adapted from `references/welcome.html`: a four-step stepper (all pending), one line per step explaining what will happen, dark clean styling. If the surface can't render HTML artifacts, fall back to a markdown checklist — never block on the visual.

**Re-render the visual after each step completes**, with that step marked done and the next active. The visual is presentation-only: every choice is made by the user replying in chat.

### Step 1 — Connect

Run `doctor`. Three cases:
- Credentials present and working → mark done, show tenant + scopes.
- No config → run the sibling `login` flow conversationally (never echo the secret; it stores to `~/.summation/skill-config`, 0600).
- Config present but failing → diagnose per the `doctor` skill, fix or re-login.

### Step 2 — Discover (GATE: connections AND attached datasets required)

Run `preflight`. Two checks, in order — **both must pass before steps 3–4**:

**Zero connections → the onboarding PAUSES here. Do not proceed to steps 3 or 4. Do not suggest reports.**
- Mark step 2 "action needed" (amber `blocked` state in the visual); steps 3–4 stay pending.
- Tell the user plainly: no data sources are connected yet, so there is nothing real to analyze. Any tables preflight shows in this state are Summation **system tables, not business data** — never present them as a data map.
- Offer both paths: **(a) connect it right here** — hand off to the sibling `connect` skill (collects non-secret settings in chat, takes the secret via a local file so it never enters the conversation, creates + tests the connection); **(b) the workspace → Connections page** if they prefer the webapp. Never ask for a password in chat; if one gets pasted anyway, follow the `connect` skill's salvage rule (proceed + advise rotation), don't bounce them.
- After a connection is created (either path): re-run `preflight` and continue from here.

**Gate 2b — `sections.connections.datasets_total` must be > 0.** A connection is a credentialed pipe; only **attached datasets** are analyzable. Browsable source databases/tables (`browse_connection_resources`) are what *could* be attached — they are NOT data and never clear this gate. If `datasets_total` is 0:
- Keep step 2 in the amber `blocked` state. Do not proceed. Do not introduce Addison to an empty room.
- Optionally browse the connection (`call POST /v1/connections/<ID>/resources --body '{"max_results": 200}'`) and show the tree as a **preview of what they can attach** — labeled exactly that way.
- Hand off: open the connection in workspace → **Connections**, attach the datasets (tables) they want analyzed. (No public API for dataset attachment yet — this step is webapp-only.)
- Resume on "done": re-run `preflight`; `datasets_total > 0` clears the gate.

**Both gates pass** → update the visual with the **source map** panel: connected systems (one-line summaries from connections, including dataset counts), tables/views/projects counts, notable table names — all mirrored from preflight output verbatim.

### Step 3 — Meet Addison

Addison is Summation's analyst agent. Ensure a project: list projects; if none, propose creating one named `getting-started` and create it only after the user agrees. Then open a conversation:

```bash
python3 ../api/scripts/sum_api.py call --stream \
  POST /v1/projects/<PROJECT_ID>/conversations \
  --body '{"message": "A new user just connected. In 3 short bullets, introduce what you can do with the data you can see, then propose 3 specific, runnable report ideas based on the actual tables available. Keep it under 120 words."}'
```

**If the conversation fails server-side** (agent infra can be down in some environments): say Addison is unavailable right now, and generate the 3 report suggestions yourself from the preflight table names instead. The onboarding must not dead-end.

### Step 4 — First report

Update the visual: numbered report-idea cards (title + one-line what-you'll-learn). Then ask the user directly: "Want me to run one of these? Reply 1, 2, 3 — or describe your own." On yes → hand off to the `report` skill pipeline (snapshot ids → generate → export **markdown** → show it → offer `/sum:validate`). Mark step 4 done in the final visual, with the report path and a "what's next" line (`/sum:query`, `/sum:catalog`, `/sum:report`).

## Rules

- **`datasets_total` is the source of truth for "data is analyzable" — never table counts, never browsable sources.** Every tenant carries internal/grid system tables (table counts prove nothing), and a connection's reachable databases are merely attachable (browse output proves nothing). Never assume, invent, or embellish data; the source map mirrors `preflight` output exactly.
- Visual first, then work; one visual updated through the flow, not four separate ones.
- Never **ask** for database passwords or connection secrets in chat. The `connect` skill owns secret transit (local-file handoff preferred; pasted-secret salvage with rotation advice as fallback; webapp always offered).
- Each step's failure has a graceful path; never show a stack trace — surface the `request_id` and continue where possible.
- Whole flow should feel under five minutes; if report generation is slow, say so and stream progress rather than going silent.

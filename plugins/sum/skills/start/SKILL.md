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

### Step 2 — Discover

Run `preflight`. Update the visual with a **source map** panel: connected systems (from connections, one-line summaries), tables/views/projects counts, notable table names. If there are **zero data connections**, say so plainly and point the user to their Summation workspace's **Connections** page to add one (database credentials are never collected in this chat) — then continue with whatever tables exist.

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

- Visual first, then work; one visual updated through the flow, not four separate ones.
- Never collect database passwords or connection secrets in chat — data sources are configured in the Summation webapp.
- Each step's failure has a graceful path; never show a stack trace — surface the `request_id` and continue where possible.
- Whole flow should feel under five minutes; if report generation is slow, say so and stream progress rather than going silent.

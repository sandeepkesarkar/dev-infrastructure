# Plan of Record — FieldKit Evolution
**Date:** 2026-08-13
**Status:** Approved direction from brainstorming session. No code written yet — spec-first, always.

---

## Uber Goal

Demonstrate effective use of GenAI and agents to develop complex systems, as the foundation for launching a consulting business. Everything below is both a real product decision and public proof of capability.

---

## Strategic Pivot: Mac Mini → Cloud

The original plan (dedicated Mac Mini physically transferred to the client to eliminate per-API-call AI costs) is **retired**. Rationale:

- Small business owners do not want to manage their own infrastructure.
- Security risk: a small business owner's self-hosted setup is an easy target; centralizing in cloud lets the software vendor own security and regular updates.
- New value proposition: **an intelligent co-worker in the cloud**. The business owner's job is to feed it information and make it smarter about their business; the vendor's job is to keep it secure, updated, and running.

The Mac Mini (`servicehub-dev`) remains permanently as my personal dev machine and Omnigent host.

---

## Workstreams

Four enhancements, **treated as separate workstreams**, plus one foundational workflow that all of them flow through.

### Foundation — GitHub Task Workflow (dev-infrastructure)

All work moving forward is created as GitHub issues and executed by agents through GitHub. Human judgment enters at exactly two points: approving the issue breakdown, and reviewing/merging PRs.

**Decided parameters:**

| Parameter | Decision |
|---|---|
| Spec → issue decomposition | Done by an agent; I read and approve before issues are created |
| Issue sizing heuristic | Deliverable must be "reviewable in under 15 minutes" by a human |
| Labels (initial) | `agent-ready`, `needs-approval`, `spec`, `code`, `docs`, `content` |
| Label glossary | Standalone doc in dev-infrastructure; referenced by all workflow-compatible repos (pending final confirmation) |
| Pickup mechanism | Start: (b) agents poll for `agent-ready` label. Later: (c) event-driven via webhooks/Actions, then (d) orchestrator agent triages and dispatches |
| Polling | Agent runs on the Mac Mini; 10-minute cadence; manual trigger also supported |
| Merge policy | Human merges everything. No auto-merge for now |
| Model routing | All-Anthropic to start; multi-model routing (incl. local models) introduced later |
| Code standards | Detailed comments; Mermaid diagrams wherever possible (native GitHub rendering); all code must have tests. These are acceptance criteria on every issue |
| Agent narration | One summary comment on the issue + the PR description. Expand later |
| Reusable skill | "Split this spec into issues" packaged as a reusable skill/command — the workflow's front door |
| Repo scope | fieldkit first; the future deploy repo is born workflow-compatible; **all** work (code and non-code: specs, docs, LinkedIn content) flows through issues |
| Where the spec lives | dev-infrastructure documentation (personal engineering system), NOT fieldkit — clients don't need it |

**Repo rename:** `mac-mini-dev-setup` → `dev-infrastructure` (scope grew from machine setup to the whole personal engineering system: machine + Omnigent + GitHub workflow). **Done** — GitHub repo renamed, local remote and directory updated, 2026-08-13.

**Spec drafted:** [specs/github-task-workflow.md](specs/github-task-workflow.md) + [specs/labels.md](specs/labels.md), 2026-08-13. Pending review.

---

### W1 — OpenClaw → Hermes (fieldkit)

Swap the agent runtime from OpenClaw to Hermes (`github.com/NousResearch/hermes-agent`).

**Decisions:**
- **Why:** Hermes runs easily in cloud (a $5 VPS, or serverless backends like Modal/Daytona) — aligned with the cloud pivot. Also has native multi-platform messaging gateway (Telegram, Discord, Slack, WhatsApp, Signal, Email) and built-in cron.
- **Hard swap.** Hermes becomes "required, not optional" the way OpenClaw was. FieldKit is not runtime-agnostic.
- **Start from scratch.** Do not use `hermes claw migrate`; no OpenClaw state carried over.
- **Scope: fieldkit only.** No changes to servicehub — it is being retired.
- **Interim home:** Hermes runs on the Mac Mini for development; OpenClaw gets uninstalled.
- **Model providers:** Anthropic by default; OpenAI supported as a per-client configuration choice. Everything else identical between providers.
- **Demo customers:** Create two demo customers as first-class FieldKit artifacts — one Anthropic-backed, one OpenAI-backed — under the Option C monorepo model (each gets its own complete spec-kit instance). Every future capability gets tested against both.
- **Governance parity:** All existing human-in-the-loop approvals preserved (customer-facing content approval, daily API budget caps, privacy rules: EXIF stripping, no location data, PII detection).
- **Email channel:** Open question — Gmail API polling (original Phase 1 spec) vs. Hermes native email gateway. To be discussed when planning the feature. Deciding principle: **easier to manage in the long run wins.**
- **Definition of done:** At minimum, the current system working on Hermes (parity).
- **Execution:** The Hermes swap itself is executed *through* the new GitHub task workflow (dogfooding from day one).

---

### W2 — Omnigent for Development (dev-infrastructure)

Adopt Omnigent (`github.com/omnigent-ai/omnigent`, alpha v0.3.0) on the Mac Mini for my own development workflow. Not part of the client-facing runtime.

**Decisions:**
- **Motivation:** Not pain with Claude Code. Goal is to use different models for different tasks — including local models (on the Mac Mini or in cloud) — to save Claude/OpenAI tokens, and to operate as a **highly effective team of engineers, not one person**.
- Omnigent supplies the workers; GitHub (Foundation workflow) supplies the work; I am the tech lead reviewing PRs.
- Testing done privately first; LinkedIn article about it planned for later.
- Note for later: Omnigent can run Hermes as a harness — W1/W2 intersection exists but workstreams stay separate.

---

### W3 — Cloud Setup Per Vendor (new open-source repo)

Each vendor (small business client — e.g., the pilot client) gets their own cloud deployment on their own accounts.

**Decisions:**
- Delivered as a **new open-source repo** (name TBD), born compatible with the GitHub task workflow.
- Provider candidates to brainstorm when this workstream starts: AWS, Google Cloud, Modal, Daytona, Blaxel, Islo, E2B, CoreWeave, Kubernetes, OpenShell, Boxlite, Databricks sandboxes.

**Parked/flagged (must resolve during W3 spec):**
- Account ownership vs. vendor management tension: if the client owns the cloud account but the vendor handles security and updates, standing cross-account admin access (IAM/trust design) is required. If the vendor owns the account and bills through, the model is closer to SaaS with different liability. Not yet decided.

---

### W4 — salestools-analyst × FieldKit Integration

Integrate the `salestools-analyst` repo (locally-run sales-data Q&A assistant using fine-tuned models hosted on my Hugging Face account) with FieldKit so business owners can ask questions about their business.

**Decisions:**
- Integration shape: **MCP server** — exposed as a tool the agent runtime calls.
- Initial scope: integrate the **current sales demo** as-is; detailed design (client data sources, what pilot-client data it points at) comes later.

**Parked/flagged (must resolve during W4 spec):**
- Inference hosting: HF endpoints vs. running models in the client's cloud environment — cost/latency decision that intersects with W3.

---

## Delivery Order

1. **GitHub task workflow spec** (dev-infrastructure) — everything downstream depends on it
2. **LinkedIn article draft** (pivot story) — parallel track, independent of code
3. **Omnigent setup spec** (dev-infrastructure)
4. **Hermes runtime spec** (fieldkit) — decomposed into issues via the new skill; dogfooding begins
5. W1 execution → demo customers → W3 → W4 (detailed specs deferred until reached)

---

## Content Plan

- **Next piece:** the Mac Mini → cloud pivot, published as a **LinkedIn article** with a promotional post.
- **Tone:** candid — the original plan's flaws are acknowledged honestly, not spun as planned evolution.
- **Framing:** improvement/learning narrative, NOT "OpenClaw out, Hermes in" tool churn. Title should reflect how the system is improving.
- Weekly cadence continues (reduced from twice-weekly for sustainability).
- Note: last published post celebrated the Mac Mini strategy (`2026-05-04.md`); `2026-05-11.md` (FieldKit repo launch) was ready to publish as of last update.

---

## Working Principles (unchanged, reaffirmed)

- **Spec-first, always** — full specification before any code
- **Framework-first framing** — every decision made through the lens of a reusable multi-client framework
- **Sustainability over ambition**
- **Clean boundaries** — stub out future work rather than scope-creep
- **Option C monorepo** — each client gets their own complete spec-kit instance
- **Human-in-the-loop** for all customer-facing content and now for all agent-produced PRs

---

## Open Items

1. ~~Confirm: label glossary lives as a standalone doc in dev-infrastructure referenced by all workflow-compatible repos~~ **Confirmed** — see [specs/labels.md](specs/labels.md)
2. ~~Choose first deliverable to draft: workflow spec vs. LinkedIn article~~ **Decided** — workflow spec first; drafted in [specs/github-task-workflow.md](specs/github-task-workflow.md), pending review
3. LinkedIn article title (candidates proposed, none selected)
4. Demo customer names
5. W3 account-ownership model
6. W4 inference hosting location
7. Email channel mechanism for Phase 1 under Hermes (Gmail API vs. Hermes gateway)

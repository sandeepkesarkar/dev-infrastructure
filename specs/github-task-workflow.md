# Spec: GitHub Task Workflow

**Created**: 2026-08-13
**Status**: Draft — pending review
**Repo**: dev-infrastructure (personal engineering system; not fieldkit)

## Purpose

All work — code and non-code alike (specs, docs, LinkedIn content) — is created as GitHub issues and executed by agents through GitHub. Human judgment enters at exactly two points: **approving the issue breakdown**, and **reviewing/merging PRs**. This is the foundation every other workstream in [plan-of-record-2026-08-13.md](../plan-of-record-2026-08-13.md) flows through.

## Scope

- First repo: `fieldkit`.
- Born-compatible: the future W3 cloud-deploy repo, and `dev-infrastructure` itself (this spec is dogfood #1 — it gets decomposed into issues here, once the decomposition skill exists).
- Applies to **all** work types, not just code: specs, docs, and content (e.g. LinkedIn articles) flow through the same issue-based process.

## Out of Scope (this iteration)

- Event-driven pickup (webhooks/GitHub Actions) — later evolution of the pickup mechanism.
- Orchestrator agent that triages and dispatches — later evolution.
- Auto-merge of any kind.
- Multi-model routing (including local models) — routing logic should not preclude this later, but it isn't built now.

## Roles

- **Human (Sandeep)**: approves issue breakdowns before they're created; reviews and merges every PR.
- **Decomposition agent**: reads a spec, proposes an issue breakdown, waits for approval before creating anything.
- **Worker agent**: polls for `agent-ready` issues on the Mac Mini, does the work, opens a PR, narrates.

## Scenarios

### 1. Spec → issues (P1)
Given an approved spec doc, when I invoke the "split spec into issues" skill, then it proposes a breakdown (titles, bodies, labels, acceptance criteria) for my review — no issues exist on GitHub yet.
Given I approve the breakdown, when I confirm, then the skill creates the issues with the correct labels.

### 2. Agent picks up work (P1)
Given an issue labeled `agent-ready`, when the polling agent runs (every 10 minutes on the Mac Mini, or is triggered manually), then it claims the issue, does the work, and opens a PR that references the issue.

### 3. Human reviews and merges (P1)
Given an open PR from a worker agent, when I review it, then I can read a one-line summary comment on the issue and a full PR description, see tests included for any code change, see Mermaid diagrams wherever the change benefits from one (GitHub renders these natively), and — for code PRs — see a cross-vendor (Codex) review comment covering Engineering and Security already posted. I merge by hand; there is no auto-merge path.

### 4. Issue sizing (P2)
Given a spec being decomposed, each resulting issue's deliverable must be reviewable by a human in under 15 minutes. This is the sizing heuristic the decomposition agent applies.

## Functional Requirements

- **FR-001**: The decomposition agent MUST propose an issue breakdown from a spec and MUST NOT create any issue without explicit human approval of the breakdown.
- **FR-002**: Every issue MUST carry at least one type label (`spec`, `code`, `docs`, `content`) plus applicable workflow-state labels (`agent-ready`, `needs-approval`) — see [labels.md](labels.md).
- **FR-003**: The label glossary MUST be centralized in `dev-infrastructure/specs/labels.md`; other workflow-compatible repos reference it rather than keeping their own copy.
- **FR-004**: The worker agent MUST run on the Mac Mini, polling for `agent-ready` issues on a 10-minute cadence, with a manual trigger also supported. Concrete implementation: an Omnigent scheduled session (RRULE) dispatching Polly per issue — see [omnigent-setup.md](omnigent-setup.md).
- **FR-005**: All merges MUST be performed by a human. No automated merging, in any repo, for any issue type.
- **FR-006**: Every PR from a worker agent MUST include: a one-line summary comment on the source issue, a full PR description, tests for any code change, and Mermaid diagrams wherever the change benefits from one.
- **FR-007**: Model routing MUST default to Anthropic models for all agents in this iteration, and MUST be architected so multi-model routing (including local models) can be introduced later without a workflow redesign.
- **FR-008**: "Detailed comments," "tests included" (code issues), and "Mermaid diagrams where applicable" MUST appear as standing acceptance criteria on every issue the decomposition agent creates — not just as an informal norm.
- **FR-009**: The spec→issues capability MUST be packaged as a reusable, invocable skill/command — the front door to this workflow — usable from `fieldkit`, `dev-infrastructure`, and future workflow-compatible repos.
- **FR-010**: The workflow MUST handle non-code deliverables (specs, docs, content) through the same issue-based flow, distinguished only by label.
- **FR-011**: Every code PR MUST carry a cross-vendor review (from a vendor other than the implementer, covering at minimum Engineering and Security) before being labeled `needs-approval`. Concrete implementation: Polly's Codex-reviewer dispatch against the review contract — see [omnigent-setup.md](omnigent-setup.md).

## Key Entities

- **Issue** — unit of work; carries type + state labels, acceptance criteria, and a link back to the spec it was decomposed from.
- **Label glossary** — canonical label list and meaning; single source of truth in `specs/labels.md`.
- **Worker agent** — the polling process on the Mac Mini that claims `agent-ready` issues and produces PRs.
- **Decomposition skill** — turns an approved spec into a proposed issue breakdown; nothing is created until the human approves it.

## Success Criteria

- **SC-001**: A spec goes from "approved" to "issues filed on GitHub" via a single skill invocation plus one human approval step.
- **SC-002**: 100% of agent-authored PRs carry the required narration (issue comment + PR description) before merge.
- **SC-003**: Every merged PR was reviewable in under 15 minutes (spot-checked against the sizing heuristic).
- **SC-004**: Zero auto-merges — every merge in the GitHub audit log has a human actor.
- **SC-005**: This spec is itself decomposed into issues and executed through the workflow it describes (dogfooding), and the Hermes swap (W1) is the first non-trivial workstream to run entirely through it.
- **SC-006**: Zero code PRs reach `needs-approval` without a cross-vendor review comment already attached.

## Bootstrapping Note

The decomposition skill doesn't exist yet — it's one of the deliverables this spec produces. This spec's own first pass into issues will necessarily be done by hand (or semi-manually, with an agent's help but no packaged skill). Once the skill exists, it becomes the only path for future specs.

## Assumptions

- Issues and PRs live on the existing GitHub repos (`sandeepkesarkar/fieldkit`, `sandeepkesarkar/dev-infrastructure`) — no separate ticketing system.
- The worker agent runs via Omnigent + Polly (see [omnigent-setup.md](omnigent-setup.md)) on the Mac Mini, with `gh` CLI access and repo write permissions.
- A 10-minute polling cadence is acceptable latency for now; revisit if it becomes a bottleneck once W1 execution starts.
- This spec supersedes no prior workflow — there isn't one; issue-based execution is new to both repos.

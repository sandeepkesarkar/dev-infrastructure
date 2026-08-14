# Spec: Omnigent for Development

**Created**: 2026-08-13
**Status**: Draft — pending review
**Repo**: dev-infrastructure (personal dev tooling; not part of fieldkit's client-facing runtime — that's [W1/Hermes](github-task-workflow.md))

## Purpose

Adopt [Omnigent](https://github.com/omnigent-ai/omnigent) (alpha, v0.3.0) on the Mac Mini as the personal development orchestration layer: route different tasks to different models — including local/gateway models where suitable — to save Claude/OpenAI tokens, and operate as a team of engineers rather than one person, with human review as the actual bottleneck by design.

## Scope

- Personal dev workflow only. Not shipped to clients; does not touch fieldkit's runtime.
- Runs on the Mac Mini (`servicehub-dev`).
- Ties directly into the [Foundation GitHub task workflow](github-task-workflow.md): Omnigent's own scheduler implements that spec's FR-004 (10-minute `agent-ready` polling) — see Decisions below.

## Out of Scope (this iteration)

- Broader local-model *implementation* work. Only review/explore/search route to local or gateway models (via the `pi` worker) in v1 — see Decisions.
- Multi-user accounts, OIDC login, a cloud-hosted server, or phone access. Single-operator, local setup for now.
- Orchestrator-agent triage/dispatch beyond simple label-based polling — that's the Foundation workflow's later phase (d), not this.

## Decisions

- **Motivation is throughput, not a Claude Code complaint.** The goal is model diversity and running as a team, not fixing something broken.
- **Adopt Polly, don't build from scratch.** Omnigent ships an example orchestrator agent (`examples/polly/`) that already implements the target shape: it writes no code itself, decomposes a goal, delegates every coding task to a sub-agent (`claude_code`, `codex`, `cursor`, `hermes`, `opencode`, `agy`) in its own git worktree, and routes every diff to a **reviewer from a different vendor than the implementer** before it's presented as ready — only implementers open PRs, and Polly never merges. That is the "tech lead reviewing PRs, not writing code" role from the plan, already built and tested upstream. Adopt it as-is; customize only once real usage surfaces a concrete need.
- **Omnigent's scheduler is the Foundation's polling mechanism.** Omnigent has a native scheduled-tasks feature (RRULE-based recurring sessions). Rather than a separate cron/launchd job, a scheduled Omnigent session polls `agent-ready` issues and dispatches Polly — this is the concrete implementation of [github-task-workflow.md FR-004](github-task-workflow.md).
- **Local models: `pi`-only for v1.** Of Polly's sub-agents, only `pi` can run an arbitrary gateway model (Ollama, OpenRouter, etc.); the other implementers run their own vendor's models. So local/gateway routing lands on review/explore/search work, not full implementation, for now. Broader local-model implementation is deferred, not ruled out.
- **Configuration is committed, not machine-local.** Polly's config, the poller agent, and policy definitions live in `dev-infrastructure/omnigent/` under version control — consistent with spec-first, framework-first principles.
- **Hermes note (carried from plan-of-record):** Omnigent can run Hermes as a harness (`omnigent hermes`). W1 and W2 intersect at that point, but stay separate workstreams — W2 doesn't change W1's fieldkit runtime decisions.
- **Codex is a required reviewer, not opportunistic.** FR-003 originally treated non-Anthropic vendor CLIs as "used opportunistically... not required for v1." Superseded: Codex specifically MUST be installed and available so Polly's roster preflight finds it, because Codex-reviews-before-Sandeep-reviews is now a deliberate workflow requirement (an independent-vendor pass before human review), not an incidental benefit of having multiple CLIs installed. Codex CLI (`@openai/codex` via npm) is installed and authenticated on the Mac Mini as of 2026-08-14.
- **Codex auth is an API key, not the ChatGPT subscription.** Codex CLI supports headless ChatGPT-subscription login (`codex login --device-auth`), but OpenAI's own docs recommend API-key auth for CI/automation-shaped usage and flag that subscription refresh tokens can go stale after ~8 days of inactivity — a real risk for a reviewer that only runs when a PR happens to be ready. Authenticated via `printenv OPENAI_API_KEY | codex login --with-api-key`, mirroring the Anthropic-API-key-over-Claude-Pro decision made for the gateway itself (see fieldkit's `platform/docs/hermes/02-gateway-setup.md`).
- **Review scope is a versioned, extensible contract — not an inline prompt.** What a reviewer checks (and how it reports findings) lives in [`omnigent/polly/skills/pr-review.md`](../omnigent/polly/skills/pr-review.md), not hand-written into Polly's dispatch prompt each time. Starts with two dimensions — Engineering and Security — with a stable output format designed so new dimensions can be added by editing that one file, without touching Polly's config or the dispatch mechanism.

## Architecture

### Components

1. **Polly** (`examples/polly/`) — the orchestrator. Decomposes a goal, delegates implementation to sub-agents in isolated worktrees, routes each diff to a different-vendor reviewer, reports via the inbox. Never merges.
2. **Poller** (new, thin) — a scheduled Omnigent session (RRULE, 10-minute cadence, manual trigger also supported) that runs `gh issue list --label agent-ready` across workflow-compatible repos and, for each unclaimed issue, dispatches a Polly session with the issue body as its goal.
3. **Policies** — Omnigent's builtin `cost_budget` (hard cap + soft warning threshold) and `max_tool_calls_per_session`, configured at the server or per-agent level — the same governance shape already required for fieldkit under W1.
4. **Review contract** (`omnigent/polly/skills/pr-review.md`) — the versioned, extensible checklist a reviewer sub-agent loads and follows: what to check (Engineering, Security, and future dimensions) and the structured output format for its findings. Polly's dispatch task description references this file rather than restating the checklist inline.

### Model routing

- Default brain/implementer models: Anthropic (Claude), consistent with the Foundation spec's FR-007 all-Anthropic default.
- `pi` worker: local/gateway model (Ollama on the Mac Mini, or another compatible gateway) for review/explore/search — the actual token-saving lever in v1.

## Scenarios

### 1. I hand Polly a dev task (P1)
Given a task described in chat or a claimed GitHub issue, when I (or the poller) start a Polly session with it as the goal, then Polly decomposes it, dispatches implementer(s) in worktree(s), and reports back via the inbox when a PR is ready for my review.

### 2. Cross-vendor review happens automatically (P1)
Given an implementer's PR, when Polly's roster preflight finds at least two available vendors, then a reviewer from a different vendor checks the diff against the task's acceptance contract before the PR is presented as ready. If fewer than two vendors are available, Polly says so explicitly rather than skipping review silently. For fieldkit, the reviewer MUST be Codex specifically (not an arbitrary other vendor), applying every dimension currently defined in [`omnigent/polly/skills/pr-review.md`](../omnigent/polly/skills/pr-review.md), with its findings posted as a PR comment before the PR is labeled `needs-approval`.

### 3. The poller claims agent-ready issues on a cadence (P1)
Given an issue labeled `agent-ready` in `fieldkit` or `dev-infrastructure`, when the scheduled poller runs (every 10 minutes, or triggered manually), then it starts a Polly session scoped to that issue and does not re-claim an issue already in flight.

### 4. Spend stays capped (P2)
Given a running session, when cumulative cost approaches the configured soft threshold, then I'm asked before continuing; when it hits the hard cap, the session stops.

## Functional Requirements

- **FR-001**: Omnigent MUST run on the Mac Mini via the standard installer (`omnigent`/`omni` CLI; requires Python 3.12+, `uv`, Node 22 LTS, `tmux`).
- **FR-002**: The dev orchestrator MUST be Omnigent's shipped Polly agent, adopted as-is for v1.
- **FR-003**: Polly's sub-agent roster MUST default to Anthropic-backed harnesses; other vendor CLIs are used opportunistically for cross-vendor review where installed, not required for v1 — **except Codex, which is required** (see FR-010).
- **FR-010**: Codex CLI MUST be installed and authenticated via `OPENAI_API_KEY` (not ChatGPT-subscription login) on any machine running Polly, so roster preflight finds it. For workflow-compatible repos (starting with fieldkit), Codex MUST be the reviewer for every implementer-authored PR.
- **FR-011**: Every cross-vendor review dispatch MUST apply the dimensions currently defined in [`omnigent/polly/skills/pr-review.md`](../omnigent/polly/skills/pr-review.md) and report findings in that file's output format, posted as a PR comment. New review dimensions are added by editing that file; no change to Polly's config or dispatch logic is required.
- **FR-004**: A scheduled Omnigent session (RRULE, 10-minute cadence, manual trigger supported) MUST poll `agent-ready` issues across workflow-compatible repos and dispatch one Polly session per issue. This satisfies [github-task-workflow.md FR-004](github-task-workflow.md); no separate cron/launchd mechanism is used.
- **FR-005**: `pi` MUST be configured with a local or gateway model (e.g. Ollama) available for review/explore/search dispatches.
- **FR-006**: Cost governance MUST be configured via Omnigent's builtin `cost_budget` policy (hard cap + soft warning threshold) at the server or agent level.
- **FR-007**: Every implementer-authored PR MUST carry a co-author trailer identifying it as agent-produced, consistent with the Foundation spec's FR-006 narration requirement.
- **FR-008**: Agent configuration (Polly's config, the poller agent, policy definitions) MUST be committed into `dev-infrastructure` under version control.
- **FR-009**: Omnigent adoption MUST NOT alter fieldkit's client-facing runtime decisions (W1/Hermes) — this workstream is dev-tooling only.

## Key Entities

- **Polly session** — one orchestrator run against one goal (a chat-provided task or a claimed issue); owns delegation, review routing, and inbox reporting.
- **Poller session** — the scheduled Omnigent session that turns `agent-ready` issues into Polly dispatches.
- **Policy** — a cost/tool-call governance rule applied server-wide, per-agent, or per-session.

## Success Criteria

- **SC-001**: A dev task goes from "described to Polly" to "PR open, cross-vendor reviewed" without me writing code directly.
- **SC-002**: The poller correctly claims and dispatches `agent-ready` issues on the Foundation's 10-minute cadence without manual intervention.
- **SC-003**: At least one review/explore task per week runs on a local/gateway model via `pi`, measurably reducing Claude/OpenAI token spend.
- **SC-004**: No session exceeds its configured cost cap without an explicit approval.
- **SC-005**: This spec is itself decomposed into issues and executed through the Foundation workflow (dogfooding continues).
- **SC-006**: Every fieldkit PR carries a Codex review comment (Engineering + Security dimensions, per the review contract) before it is labeled `needs-approval`.

## Assumptions

- The Mac Mini has, or will have, `uv`, Node 22 LTS, `tmux`, and the relevant coding-harness CLIs available per Omnigent's prerequisites.
- Anthropic remains the default credential; other vendor CLIs are added opportunistically, not as a blocking requirement.
- Testing happens privately first (per plan-of-record); no multi-user features are needed yet.
- Omnigent is alpha software (v0.3.0 at time of writing) — breaking changes are possible; this spec may need revision as the project matures.

## Open Questions

- Whether the poller should be one shared scheduled session covering both `fieldkit` and `dev-infrastructure`, or one per repo — leaning toward one shared session for simplicity, revisit if the repos' cadence needs diverge. Moot until the `dev-infrastructure`-only dogfood phase (below) graduates to including `fieldkit`.

## Rollout Phase

Decided 2026-08-14, before any of this is installed:

- **Cost cap: `max_cost_usd: 5.00` per session**, via Omnigent's builtin `cost_budget` policy (FR-006). Starting number with no usage data yet; revisit after a week of real Polly runs.
- **Dogfood on `dev-infrastructure` first, not `fieldkit`.** Omnigent is alpha (v0.3.0-era) and Polly/the poller aren't installed yet. The poller's initial scope is `dev-infrastructure` only — prove the full loop (poller claims issue → Polly delegates → Codex reviews per the contract → PR opens → human merges) on low-stakes dev-tooling issues before pointing it at client-facing `fieldkit` work. Expanding poller scope to include `fieldkit` is a separate, later decision, not assumed here.
- **Sandboxing: local (macOS `seatbelt`), not a cloud sandbox provider.** Single machine, single operator, own repos — no multi-tenant isolation need that would justify Modal/E2B/Databricks.
- **Still single-operator.** No OIDC, no multi-user accounts (`OMNIGENT_AUTH_ENABLED`), no phone access — unchanged from the original Decisions above.

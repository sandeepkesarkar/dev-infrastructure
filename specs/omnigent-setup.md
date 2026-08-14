# Spec: Omnigent for Development

**Created**: 2026-08-13
**Status**: Draft — pending review
**Repo**: dev-infrastructure (personal dev tooling; not part of fieldkit's client-facing runtime — that's [W1/Hermes](github-task-workflow.md))

## Purpose

Adopt [Omnigent](https://github.com/omnigent-ai/omnigent) (alpha, v0.3.0) on the Mac Mini as the personal development orchestration layer: route different tasks to different models — including local/gateway models where suitable — to save Claude/OpenAI tokens, and operate as a team of engineers rather than one person, with human review as the actual bottleneck by design.

## Scope

- Personal dev workflow only. Not shipped to clients; does not touch fieldkit's runtime.
- Runs on the Mac Mini (`servicehub-dev`).
- Ties directly into the [Foundation GitHub task workflow](github-task-workflow.md): a launchd job invoking the `poller` agent implements that spec's FR-004 (hourly `agent-ready` polling) — see Decisions below.

## Out of Scope (this iteration)

- Broader local-model *implementation* work. Only review/explore/search route to local or gateway models (via the `pi` worker) in v1 — see Decisions.
- Multi-user accounts, OIDC login, a cloud-hosted server, or phone access. Single-operator, local setup for now.
- Orchestrator-agent triage/dispatch beyond simple label-based polling — that's the Foundation workflow's later phase (d), not this.

## Decisions

- **Motivation is throughput, not a Claude Code complaint.** The goal is model diversity and running as a team, not fixing something broken.
- **Adopt Polly, don't build from scratch.** Omnigent ships an example orchestrator agent (`examples/polly/`) that already implements the target shape: it writes no code itself, decomposes a goal, delegates every coding task to a sub-agent (`claude_code`, `codex`, `cursor`, `hermes`, `opencode`, `agy`) in its own git worktree, and routes every diff to a **reviewer from a different vendor than the implementer** before it's presented as ready — only implementers open PRs, and Polly never merges. That is the "tech lead reviewing PRs, not writing code" role from the plan, already built and tested upstream. Adopt it as-is; customize only once real usage surfaces a concrete need.
- **The polling mechanism is `launchd`, not Omnigent's own scheduled-tasks feature — revised 2026-08-14.** Omnigent does have a native scheduled-tasks feature (RRULE-based recurring sessions via `POST /v1/scheduled-tasks` / `sys_scheduled_task_create`), and that was the original plan. It doesn't work on this deployment: the endpoint requires an authenticated "owner" identity (`require_user`), and this is a single-user local server with no accounts/OIDC login ever configured — every create attempt 401s, including from inside a live agent turn calling the MCP tool directly (not just raw HTTP). Standing up Omnigent's accounts system just to unblock an hourly cron-equivalent felt like solving the wrong problem. Instead: a `launchd` agent (`~/Library/LaunchAgents/ai.omnigent.poller.plist`, `StartInterval: 3600`) runs `omnigent/poller/run_poller.sh`, which fires `omnigent run omnigent/poller/config.yaml -p "..."` hourly — same poller agent, same dispatch-to-Polly behavior, just triggered by the OS scheduler instead of Omnigent's REST API. This is the same mechanism already running Hermes's Telegram gateway on this machine (see fieldkit's `platform/docs/hermes/02-gateway-setup.md`), so it's a known-working pattern here, not a new one. Manual trigger: `bash omnigent/poller/run_poller.sh`.
- **Local models: `pi`-only for v1.** Of Polly's sub-agents, only `pi` can run an arbitrary gateway model (Ollama, OpenRouter, etc.); the other implementers run their own vendor's models. So local/gateway routing lands on review/explore/search work, not full implementation, for now. Broader local-model implementation is deferred, not ruled out.
- **Configuration is committed, not machine-local.** Polly's config, the poller agent, and policy definitions live in `dev-infrastructure/omnigent/` under version control — consistent with spec-first, framework-first principles.
- **Hermes note (carried from plan-of-record):** Omnigent can run Hermes as a harness (`omnigent hermes`). W1 and W2 intersect at that point, but stay separate workstreams — W2 doesn't change W1's fieldkit runtime decisions.
- **Codex is a required reviewer, not opportunistic.** FR-003 originally treated non-Anthropic vendor CLIs as "used opportunistically... not required for v1." Superseded: Codex specifically MUST be installed and available so Polly's roster preflight finds it, because Codex-reviews-before-Sandeep-reviews is now a deliberate workflow requirement (an independent-vendor pass before human review), not an incidental benefit of having multiple CLIs installed. Codex CLI (`@openai/codex` via npm) is installed and authenticated on the Mac Mini as of 2026-08-14.
- **Codex and Claude both default to their subscriptions, not API keys — revised 2026-08-14.** Initially authenticated Codex via API key (`printenv OPENAI_API_KEY | codex login --with-api-key`), mirroring the Anthropic-API-key-over-Claude-Pro decision made for the Hermes gateway (see fieldkit's `platform/docs/hermes/02-gateway-setup.md`) — reasoning: OpenAI's own docs recommend API-key auth for CI/automation-shaped usage, and subscription refresh tokens can go stale after ~8 days of inactivity. **Superseded** once actual usage made API-key cost a real concern for a personal setup with an already-paid-for ChatGPT Plus subscription: re-authenticated `codex` via `codex login --device-auth` (requires enabling "Device code authorization for Codex" in ChatGPT Security Settings first), then flipped Omnigent's own credential default in `~/.omnigent/config.yaml` (`providers.codex.default: true`, removed from `providers.openai`) so every Codex dispatch — both `codex` as implementer and as the pinned cross-review reviewer — bills the subscription, not pay-per-token. Claude's brain (`claude-sdk` harness) was already defaulting to the Claude subscription with no change needed. The staleness risk is now a consciously accepted trade for a single-operator setup in regular use, not an oversight — if Codex dispatches start failing after a quiet week, re-run the device-auth login.
- **`codex-native` still billed the API key anyway — the real fix was the harness, not the credential flip.** The subscription-default flip above didn't fully work: the first real cross-review dispatch was still charged (~$1, confirmed via `codex doctor` on this machine: `mixed auth signals: ChatGPT login plus API key env var; HTTP reachability uses API-key mode`). Root cause, found by reading Omnigent's own source: `codex-native` (the harness `agents/codex/config.yaml` was set to) wraps the real `codex` CLI in a PTY/tmux terminal and inherits the full caller-process environment verbatim (`os_env: type: caller_process`) — including `OPENAI_API_KEY`, which this machine exports globally in `~/.zshrc` (Keychain-sourced) for other tools (Hermes, `pi`). Codex CLI then silently prefers that inherited env var over the ChatGPT login for actual HTTP calls, regardless of `preferred_auth_method` in `~/.codex/config.toml` — a known upstream Codex CLI bug (mixed-signal precedence doesn't honor the config once both an API key and a ChatGPT login are present). Omnigent's *non-native* `codex` harness (`omnigent/inner/codex_executor.py`) already has a purpose-built fix for exactly this — its own source comment: *"`OPENAI_API_KEY` is stripped so the codex CLI falls back to subscription auth (`auth.json`) rather than a developer API key that would charge separately."* It also hardcodes `approvalPolicy: "never"` for every turn, so the `yolo: true` bypass flag (native-only) isn't needed either. Fix: `agents/codex/config.yaml` now sets `harness: codex` (not `codex-native`) — full reasoning in that file's inline comment. Trade-off: loses the "open the live terminal and watch/take over" UI affordance for Codex specifically, which doesn't matter for headless implement/review dispatch. `claude_code` wasn't affected (no equivalent mixed-signal report), so it stays on `claude-native`.
- **Review scope is a versioned, extensible checklist inside Polly's own `cross-review` skill — not a separate file she has to be told to load.** Polly only loads skills she knows by name (`investigate`, `fanout`, `cross-review`); an unrelated `pr-review.md` she was never instructed to open would silently do nothing. So the actual mechanism is a `dev-infrastructure`-local override of the bundled `omnigent/polly/skills/cross-review/SKILL.md`, adding a "Standing review dimensions" section (Engineering, Security to start) applied on every dispatch alongside the task's own acceptance contract. New dimensions are added by editing that one section — no change to Polly's config or dispatch logic.
- **The same override pins the reviewer to `codex`.** Upstream `cross-review` picks *any* available different-vendor worker. On this machine that roster already includes `codex`, `cursor`, and `hermes` (all installed, all on `PATH`) — so without pinning, review could just as easily land on Cursor or Hermes as Codex. The override dispatches `codex` specifically, falling back explicitly (never silently) to another available vendor only when Codex was the implementer or isn't in that run's roster.

## Architecture

### Components

1. **Polly** (`examples/polly/`) — the orchestrator. Decomposes a goal, delegates implementation to sub-agents in isolated worktrees, routes each diff to a different-vendor reviewer, reports via the inbox. Never merges.
2. **Poller** (`omnigent/poller/`) — a thin agent (`config.yaml`) that runs `gh issue list --label agent-ready` (dev-infrastructure only, per Rollout Phase), claims each issue found (flips `agent-ready` → `in-progress` before dispatching, so a re-fire mid-task is a no-op), and dispatches a fresh `polly` session per issue via `sys_session_create(config_path="omnigent/polly/config.yaml", ...)` — never waits for Polly to finish. Fired hourly by `launchd` (`run_poller.sh`), with a manual-trigger path for on-demand checks.
3. **Policies** — Omnigent's builtin `cost_budget` (hard cap + soft warning threshold) and `max_tool_calls_per_session`, configured at the server or per-agent level — the same governance shape already required for fieldkit under W1.
4. **Review contract** (`omnigent/polly/skills/cross-review/SKILL.md`, a `dev-infrastructure`-local override of Polly's bundled skill) — pins the reviewer to Codex and adds the standing Engineering + Security checklist applied on every review dispatch, on top of the task's own acceptance contract.

### Model routing

- Default brain/implementer models: Anthropic (Claude), consistent with the Foundation spec's FR-007 all-Anthropic default.
- `pi` worker: local/gateway model (Ollama on the Mac Mini, or another compatible gateway) for review/explore/search — the actual token-saving lever in v1.

## Scenarios

### 1. I hand Polly a dev task (P1)
Given a task described in chat or a claimed GitHub issue, when I (or the poller) start a Polly session with it as the goal, then Polly decomposes it, dispatches implementer(s) in worktree(s), and reports back via the inbox when a PR is ready for my review.

### 2. Cross-vendor review happens automatically (P1)
Given an implementer's PR, when Polly's roster preflight finds at least two available vendors, then a reviewer from a different vendor checks the diff against the task's acceptance contract before the PR is presented as ready. If fewer than two vendors are available, Polly says so explicitly rather than skipping review silently. For fieldkit, the reviewer MUST be Codex specifically (not an arbitrary other vendor, and not whichever of Cursor/Hermes happens to also be installed) — enforced by the `cross-review` skill override, which also applies the standing Engineering + Security checklist. Cross-review loops with the implementer on blocking issues until clean before the PR is marked ready for the human to merge — it isn't a one-shot comment.

### 3. The poller claims agent-ready issues on a cadence (P1)
Given an issue labeled `agent-ready` in `fieldkit` or `dev-infrastructure`, when the scheduled poller runs (hourly, or triggered manually), then it starts a Polly session scoped to that issue and does not re-claim an issue already in flight.

### 4. Spend stays capped (P2)
Given a running session, when cumulative cost approaches the configured soft threshold, then I'm asked before continuing; when it hits the hard cap, the session stops.

## Functional Requirements

- **FR-001**: Omnigent MUST run on the Mac Mini via the standard installer (`omnigent`/`omni` CLI; requires Python 3.12+, `uv`, Node 22 LTS, `tmux`).
- **FR-002**: The dev orchestrator MUST be Omnigent's shipped Polly agent, adopted as-is for v1.
- **FR-003**: Polly's sub-agent roster MUST default to Anthropic-backed harnesses; other vendor CLIs are used opportunistically for cross-vendor review where installed, not required for v1 — **except Codex, which is required** (see FR-010).
- **FR-010**: Codex CLI MUST be installed and authenticated via `OPENAI_API_KEY` (not ChatGPT-subscription login) on any machine running Polly, so roster preflight finds it. For workflow-compatible repos (starting with fieldkit), Codex MUST be the reviewer for every implementer-authored PR.
- **FR-011**: Every cross-vendor review dispatch MUST apply the Standing review dimensions section of `omnigent/polly/skills/cross-review/SKILL.md` (this deployment's override of Polly's bundled skill) in addition to the task's own acceptance contract. New review dimensions are added by editing that section; no change to Polly's config or dispatch logic is required.
- **FR-004**: A launchd-scheduled job (hourly, `~/Library/LaunchAgents/ai.omnigent.poller.plist`) MUST fire the `poller` agent, which polls `agent-ready` issues across workflow-compatible repos and dispatches one Polly session per issue, with a manual-trigger script also available. This satisfies [github-task-workflow.md FR-004](github-task-workflow.md); Omnigent's own scheduled-tasks feature was tried first and abandoned — see Decisions.
- **FR-005**: `pi` MUST be configured with a local or gateway model (e.g. Ollama) available for review/explore/search dispatches.
- **FR-006**: Cost governance MUST be configured via Omnigent's builtin `cost_budget` policy (hard cap + soft warning threshold) at the server or agent level.
- **FR-007**: Every implementer-authored PR MUST carry a co-author trailer identifying it as agent-produced, consistent with the Foundation spec's FR-006 narration requirement.
- **FR-008**: Agent configuration (Polly's config, the poller agent, policy definitions) MUST be committed into `dev-infrastructure` under version control.
- **FR-009**: Omnigent adoption MUST NOT alter fieldkit's client-facing runtime decisions (W1/Hermes) — this workstream is dev-tooling only.

## Key Entities

- **Polly session** — one orchestrator run against one goal (a chat-provided task or a claimed issue); owns delegation, review routing, and inbox reporting.
- **Poller session** — the launchd-fired `poller` agent run that turns `agent-ready` issues into Polly dispatches.
- **Policy** — a cost/tool-call governance rule applied server-wide, per-agent, or per-session.

## Success Criteria

- **SC-001**: A dev task goes from "described to Polly" to "PR open, cross-vendor reviewed" without me writing code directly.
- **SC-002**: The poller correctly claims and dispatches `agent-ready` issues on an hourly cadence without manual intervention.
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

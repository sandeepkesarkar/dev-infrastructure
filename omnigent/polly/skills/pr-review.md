# Skill: PR Cross-Vendor Review Contract

**Status:** Draft — pending review (companion to [omnigent-setup.md](../../../specs/omnigent-setup.md))
**Used by:** Polly, when dispatching a reviewer sub-agent per [omnigent-setup.md Scenario 2](../../../specs/omnigent-setup.md)

## Purpose

Defines *what* a cross-vendor reviewer checks and *how* it reports findings, so review quality doesn't depend on whichever ad-hoc prompt Polly happens to write that day. This file is the single source of truth for review scope — Polly's dispatch task description points here rather than re-describing the checklist inline.

Designed to grow: today it covers two dimensions (Engineering, Security). Adding a third means adding a new `### N. <Dimension>` section below — no change to Polly's config, dispatch logic, or the output format.

## Boundaries (inherited from Polly's base contract)

- The reviewer receives only the diff and the task's acceptance contract — never the implementer's worktree.
- The reviewer reports findings. It never edits files and never merges.
- Only the implementer opens the PR; the reviewer's output is posted as a PR comment.

## Dispatch

Polly dispatches this as a `review` purpose task. Task description template:

```
Review this diff against the PR Review Contract (dev-infrastructure/omnigent/polly/skills/pr-review.md).
Apply every dimension currently defined in that file. Output findings using the
format in "Output format" below. If a dimension finds nothing, say so explicitly
("Engineering: no findings") rather than omitting the section — silence is
ambiguous between "checked, clean" and "not checked."
```

For fieldkit specifically, cross-vendor review MUST route to `codex` (not just "any other vendor") — see [omnigent-setup.md](../../../specs/omnigent-setup.md) Decisions.

## Review dimensions

### 1. Engineering

Same categories as the `code-review` skill Claude-side reviews already use in this codebase, so findings are comparable regardless of which vendor produced them:

- **Correctness** — logic errors, edge cases, off-by-ones, race conditions, error handling that swallows or misreports failure.
- **Simplification / reuse** — unnecessary abstraction, duplicated logic that should call existing code, over-engineering relative to what the issue actually asked for.
- **Efficiency** — avoidable N+1s, redundant work, obviously wrong complexity for the data size involved.
- **Test coverage** — new behavior without a test exercising it; a test that doesn't actually assert the thing it claims to.

### 2. Security

Baseline OWASP-shaped checks, plus this framework's own governance requirements:

- **Injection classes** — command injection, SQL injection, XSS, path traversal, unsafe deserialization.
- **Secrets handling** — credentials, tokens, or keys logged, printed, committed, or passed as CLI args (visible in process lists / shell history) instead of env/file with restricted permissions.
- **PII handling** — personal data (names, contact info, location/EXIF, chat content) logged or persisted somewhere it shouldn't be, per the constitution's Privacy gate.
- **Authn/authz** — missing or bypassable checks on who can trigger an action (e.g. an admin-allowlist check that's checked once and cached past its validity, or a webhook without signature verification).
- **Blast radius** — anything destructive (data deletion, force-push, irreversible external API calls — e.g. posting to a client's live social media) that isn't gated behind the human-approval step the constitution's HITL gate requires.

## Output format

One section per dimension, in a stable shape so a growing number of dimensions still renders as one readable PR comment:

```markdown
## Codex Review — <dimension name>

**Findings:** <N>

### <short_summary> (<severity: blocking | non-blocking>)
- **File:** path/to/file.py:123
- **Issue:** <one-sentence statement of the defect>
- **Failure scenario:** <concrete input/state → wrong output or crash>

(repeat per finding, or "No findings." if the dimension is clean)
```

`severity` is binary on purpose: **blocking** (should be fixed before Sandeep spends review time on this PR) vs **non-blocking** (worth knowing, not worth round-tripping the implementer for). Finer severity gradation is a candidate future extension — see below.

## Extending this contract

To add a new dimension (e.g. "Performance at scale," "Accessibility," "Cost/token efficiency"):

1. Add a new `### N. <Dimension>` section under **Review dimensions** with its own checklist.
2. No other file changes needed — the dispatch template already says "apply every dimension currently defined in this file."
3. If the new dimension needs a different output shape than the one above (e.g. a numeric score instead of pass/fail findings), document that under its own section rather than changing the shared **Output format** — keep the shared format the default, and let a dimension opt out explicitly if it has to.

## Open questions (carried, not resolved here)

- Whether `severity` should grow beyond blocking/non-blocking once real review volume shows the binary is too coarse.
- Whether a dimension's checklist should ever be per-repo (e.g. fieldkit's constitution gates as fieldkit-only sub-checks under Security) rather than global across all workflow-compatible repos. Leaning toward: keep this file's dimensions global/minimal, let a repo add its own `pr-review.<repo>.md` overlay later if a real need shows up — not speculatively now.

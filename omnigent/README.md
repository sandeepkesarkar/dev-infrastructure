# omnigent/

This directory holds Polly's orchestrator config for this deployment, wired
up to [agent-dev-kit](https://github.com/sandeepkesarkar/agent-dev-kit) —
the generic, reusable version of this same workflow — via a git submodule at
`.agents/agent-dev-kit`.

## What's here, and why it's split this way

```
omnigent/
├── README.md                # this file
├── poller/                  # dev-infrastructure-only; agent-dev-kit ships no poller
│   ├── config.yaml
│   └── run_poller.sh
└── polly/
    ├── config.yaml          # LOCAL — synced copy of the submodule's config.yaml, PLUS
    │                         # this deployment's cost_budget guardrail (see below)
    ├── agents -> ../../.agents/agent-dev-kit/agents   # symlink into the submodule
    └── skills -> ../../.agents/agent-dev-kit/skills   # symlink into the submodule
```

`.omnigent/config.yaml` points `default_agent` at `omnigent/polly/config.yaml`
(this local wrapper), not directly at the submodule.

### Why `polly/config.yaml` is a local file, not a pointer at the submodule

Omnigent's bundle loader (`omnigent.spec.parser.parse`) reads exactly one
`config.yaml` per bundle root — there's no `include`/`extends`/overlay
mechanism, confirmed by reading `parse()` (a single `yaml.load` call) and by
`omnigent config`'s own docs (only `default_agent`/`server`/`harness`/
`model`/`auto_open_conversation` are project-level-overridable keys —
guardrails aren't one of them). So there is currently no supported way to
point `default_agent: .agents/agent-dev-kit` straight at the submodule (the
pattern agent-dev-kit's own README documents for consumers with no local
guardrail deltas) and still layer a repo-local
`guardrails.policies.cost_budget` on top. agent-dev-kit ships with **no**
`cost_budget` on purpose — see its `config.yaml`: "a $ cap is inherently
personal" — so this deployment's cap (`max_cost_usd: 5.0`, see
`specs/omnigent-setup.md`'s Rollout Phase) has to live somewhere, and
`polly/config.yaml` is that somewhere. It is otherwise a straight copy of
`.agents/agent-dev-kit/config.yaml`; the `cost_budget` block near the end,
marked with a `# dev-infrastructure delta` comment, is the only intentional
difference.

Everything else that used to be vendored here — the two Codex-pinning /
Standing-review-dimensions deltas that used to live in a locally-forked
`cross-review/SKILL.md`, and full copies of all seven `agents/*/config.yaml`
— turned out to already be generalized upstream in agent-dev-kit once it was
extracted as its own repo (diffed line-for-line to confirm before deleting).
Those are now symlinks into the submodule instead of local copies, so they
stay pinned to whatever commit `.agents/agent-dev-kit` is bumped to, with
zero drift risk on this repo's side.

## Re-syncing `polly/config.yaml` after a submodule bump

```bash
cd .agents/agent-dev-kit && git pull origin main && cd -
git add .agents/agent-dev-kit
diff .agents/agent-dev-kit/config.yaml omnigent/polly/config.yaml
```

Pull in any upstream changes, then re-apply (or confirm still present) the
`# dev-infrastructure delta` header comment and the `cost_budget` block at
the end — that's the only intentional divergence to preserve.

## Machine-global skills

The three skills (`cross-review`, `fanout`, `investigate`) are additionally
available machine-wide via `~/.agents/skills/<name>` symlinks into a local
`~/src/agent-dev-kit` checkout, per agent-dev-kit's own README — that's a
separate, per-machine setup step, not part of this repo.

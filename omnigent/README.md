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
    │                         # this deployment's guardrail deltas (see below)
    ├── agents/               # LOCAL — vendored copy of the submodule's agents/ (see below)
    └── skills/               # LOCAL — vendored copy of the submodule's skills/ (see below)
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

### Why `polly/agents/` and `polly/skills/` are vendored copies, not symlinks

They were symlinks into the submodule at first (`agents -> ../../.agents/
agent-dev-kit/agents`, same for `skills`) — zero drift risk on paper, since
they'd always resolve to whatever commit `.agents/agent-dev-kit` was pinned
to. **This turned out to be broken for actual interactive use** (found
2026-08-31, tracing a real `omnigent` launch failure: "tools.agents:
references sub-agent 'claude_code' but no sub-agent under agents/ declares
that name" — repeated for every declared sub-agent).

Root cause, confirmed directly against the installed Omnigent CLI source:
`omnigent run <dir>` (and bare `omnigent`, which is shorthand for it) walks
a directory target with `Path.rglob("*")` to build the tarball it uploads
to the daemon (`omnigent/cli.py:_bundle()`) — and `rglob` does **not**
descend into symlinked subdirectories. With `agents/`/`skills/` as
symlinks, the uploaded bundle silently contained zero files under either
path (empirically confirmed: `rglob` found 1 file total, 0 under either
directory), so the server rejected the resulting spec as if no sub-agents
were declared at all. This is a real gap in Omnigent's own bundling code —
`_preregister_agent` (the server's `--agent` flag) and the standalone-YAML
branch of `_bundle()` both go through `materialize_bundle`
(`shutil.copytree`, which *does* follow symlinks correctly), but the
directory branch of the client-side `_bundle()` doesn't use that same
helper. Local `parse()`/`validate()` calls never caught this because plain
filesystem reads follow symlinks transparently — only this one archiving
step doesn't. Worth filing upstream, but not something this repo controls
the fix for, so vendoring is the fix on this side.

## Re-syncing after a submodule bump

```bash
cd .agents/agent-dev-kit && git pull origin main && cd -
git add .agents/agent-dev-kit
diff .agents/agent-dev-kit/config.yaml omnigent/polly/config.yaml
diff -rq .agents/agent-dev-kit/agents omnigent/polly/agents
diff -rq .agents/agent-dev-kit/skills omnigent/polly/skills
```

For `config.yaml`: pull in any upstream changes, then re-apply (or confirm
still present) the `# dev-infrastructure delta` header comment and the
`guardrails.policies.{cost_budget,diagnostic_tool_call_logger}` block at
the end — that's the only intentional divergence to preserve.

For `agents/` and `skills/`: these have no intentional local divergence at
all (unlike `config.yaml`), so a clean re-sync is just replacing them
wholesale —

```bash
rm -rf omnigent/polly/agents omnigent/polly/skills
cp -R .agents/agent-dev-kit/agents omnigent/polly/agents
cp -R .agents/agent-dev-kit/skills omnigent/polly/skills
```

The same `TODO` from the config.yaml re-sync applies here too: nothing yet
catches this repo's copies silently falling behind the submodule between
bumps — worth a CI check that diffs all three (`config.yaml` guardrails
normalized out, `agents/`, `skills/`) against the submodule and fails on
any unexpected difference.

## Launching from a multi-repo parent folder

If `agent-dev-kit`, `dev-infrastructure`, and one or more product repos
(e.g. `fieldkit`) live as siblings under one workspace folder, that parent
folder is not itself a git repo — it has no `.agents/`, no submodule, and
Omnigent's own global config (`~/.omnigent/config.yaml`) has no
`default_agent` set by default. Launching bare `omnigent` from there with
no setup falls back to Omnigent's own generic, shipped example agent —
none of the three repos' actual bundles — and its `agents/` roster won't
match anything you dispatch to.

To make the parent folder default to this repo's bundle instead, create
`<parent>/.omnigent/config.yaml` (machine-local; the parent isn't a repo,
so nothing here is git-tracked) with:

```yaml
default_agent: /absolute/path/to/dev-infrastructure/omnigent/polly
```

Two non-obvious requirements, both confirmed 2026-08-31 by tracing real
launch failures against the installed Omnigent CLI source (not guessed):

- **Must be an absolute path.** A relative path (e.g.
  `dev-infrastructure/omnigent/polly/config.yaml`) is resolved against
  whichever process's current working directory happens to read it — the
  CLI client resolves it fine, but the background Omnigent **server**
  process (which can have started from an entirely different directory,
  possibly days earlier) resolves the same relative path against its own
  cwd instead, silently failing to find the file and falling back to the
  generic built-in agent with no error pointing at the real cause.
- **Must be the bundle ROOT DIRECTORY, not a path to `config.yaml`
  itself.** `omnigent.spec.parser.parse()` expects a directory containing
  `config.yaml` (plus `agents/`/`skills/`) and looks for
  `<dir>/config.yaml` inside it; handing it the file path directly raises
  `FileNotFoundError` in isolation, and empirically routes the real CLI
  into a different code path that never resolves the sibling `agents/`
  directory at all — producing the exact same "no sub-agent under agents/
  declares that name" error the symlink bug above produces, for an
  unrelated reason. `fieldkit`'s own `.omnigent/config.yaml` already gets
  this right (`default_agent: .agents/agent-dev-kit`, a directory) — match
  that shape here too.

**A background server won't pick up a new `PYTHONPATH` (or any other env
var) just by re-running `omni server --background`.** That command reuses
a healthy already-running server silently ("Background server already
running") rather than restarting it — confirmed 2026-08-31 while trying to
make `polly_policies` (see `guardrails.policies.diagnostic_tool_call_logger`
in `polly/config.yaml`) importable. If a guardrail policy needs
`PYTHONPATH` to resolve a dotted `function.path`, changing that env var
requires an explicit `omni server stop` first, then a fresh
`PYTHONPATH=... omni server --background` — restarting stops every live
session on the machine, so treat it as disruptive, not routine.

## Machine-global skills

The three skills (`cross-review`, `fanout`, `investigate`) are additionally
available machine-wide via `~/.agents/skills/<name>` symlinks into a local
`~/src/agent-dev-kit` checkout, per agent-dev-kit's own README — that's a
separate, per-machine setup step, not part of this repo.

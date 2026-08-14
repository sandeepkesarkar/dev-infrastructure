# omnigent/

This directory holds our committed copy of [Omnigent](https://github.com/omnigent-ai/omnigent)'s
Polly orchestrator config and skills — vendored from the installed `omnigent`
package, with two intentional deltas from upstream.

## Why this is committed, not machine-local

Omnigent normally expects agent config under `~/.omnigent/`, a machine-local
install artifact. We deliberately vendor it into `dev-infrastructure/omnigent/`
instead and put it under version control.

Per `specs/omnigent-setup.md` ("Configuration is committed, not machine-local",
FR-008): Polly's config, the poller agent, and policy definitions live here so
they're spec-first and framework-first — reviewable, diffable, and
re-deployable to any machine — rather than living only as local state on the
Mac Mini that runs it.

## What's here

```
omnigent/polly/
├── config.yaml                        # Polly orchestrator config — HAS a delta, see below
├── agents/
│   ├── claude_code/config.yaml        # vendored as-is
│   ├── codex/config.yaml              # vendored as-is
│   ├── cursor/config.yaml             # vendored as-is
│   ├── hermes/config.yaml             # vendored as-is
│   ├── opencode/config.yaml           # vendored as-is
│   ├── agy/config.yaml                # vendored as-is
│   └── pi/config.yaml                 # vendored as-is
└── skills/
    ├── investigate/SKILL.md           # vendored as-is
    ├── fanout/SKILL.md                # vendored as-is
    └── cross-review/SKILL.md          # HAS a delta, see below
```

Everything under `agents/` and the `investigate` / `fanout` skills are
unmodified copies of upstream Polly. Only two files carry deltas, and each
delta is documented inline as a comment at the point of change — this README
points at them rather than duplicating their content (so they can't drift out
of sync):

- **`polly/config.yaml`** — the `guardrails.policies.cost_budget` block near
  the end of the file. Pins a cost cap (`max_cost_usd: 5.0`, with
  `ask_thresholds_usd` warnings) that upstream Polly doesn't set by default.
  See the `# dev-infrastructure delta` comment directly above that block.
- **`polly/skills/cross-review/SKILL.md`** — pins the cross-review reviewer to
  Codex specifically, with an explicit (non-silent) fallback to another
  available vendor if Codex isn't in the run's roster. See the comment block
  at the top of the file and step 3 of the Procedure section, which are
  called out as the only changes from upstream.

Both deltas are explained in more depth, with their rationale, in
`specs/omnigent-setup.md` (see "Codex is a required reviewer, not
opportunistic" and the Rollout Phase cost-cap decision).

## Re-vendoring after an `omnigent upgrade`

The source of truth upstream is the installed `omnigent` package's bundled
Polly example, not a GitHub checkout. Find it with:

```bash
python3 -c "import omnigent, os; print(os.path.join(os.path.dirname(omnigent.__file__), 'resources', 'examples', 'polly'))"
```

On this machine (via `uv tool install omnigent`), that resolves to something
like:

```
~/.local/share/uv/tools/omnigent/lib/python3.12/site-packages/omnigent/resources/examples/polly/
```

To re-sync after an `omnigent upgrade`:

1. Diff the new package's `resources/examples/polly/` against this directory's
   `omnigent/polly/`:
   ```bash
   diff -ru "$(python3 -c "import omnigent, os; print(os.path.join(os.path.dirname(omnigent.__file__), 'resources', 'examples', 'polly'))")" omnigent/polly/
   ```
2. Pull in any upstream changes (new/changed agents, new skills, changed
   defaults), being careful to preserve — or re-apply — the two documented
   deltas on top:
   - Re-add the `cost_budget` policy block to `config.yaml` if upstream
     touched the `guardrails.policies` section.
   - Re-apply the Codex-pinning changes to `cross-review/SKILL.md` (the
     header comment plus step 3 of the Procedure) if upstream changed that
     skill.
3. Confirm both delta comments are still present and accurate after the
   merge — they're what future readers (human or agent) rely on to know
   these aren't upstream bugs.

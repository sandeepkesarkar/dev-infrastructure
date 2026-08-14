# omnigent/

This directory holds our committed copy of [Omnigent](https://github.com/omnigent-ai/omnigent)'s
Polly orchestrator config and skills — vendored from the installed `omnigent`
package, with two intentional deltas from upstream.

## Why this is committed, not machine-local

Omnigent normally expects agent config under `~/.omnigent/`, a machine-local
install artifact. We deliberately vendor it into `dev-infrastructure/omnigent/`
instead and put it under version control.

Per `specs/omnigent-setup.md` ("Configuration is committed, not machine-local",
FR-008): Polly's config and policy definitions live here so they're
spec-first and framework-first — reviewable, diffable, and re-deployable to
any machine — rather than living only as local state on the Mac Mini that
runs it. The spec also calls for a poller agent (the scheduled session that
polls `agent-ready` issues and dispatches Polly, FR-004) to eventually live
under version control the same way — but as of this writing that piece isn't
built yet, so it isn't present in this directory. Only Polly's config and
skills are committed here so far.

## What's here

```
omnigent/
├── README.md                          # this file
└── polly/
    ├── config.yaml                    # Polly orchestrator config — HAS a delta, see below
    ├── agents/
    │   ├── claude_code/config.yaml    # vendored as-is
    │   ├── codex/config.yaml          # vendored as-is
    │   ├── cursor/config.yaml         # vendored as-is
    │   ├── hermes/config.yaml         # vendored as-is
    │   ├── opencode/config.yaml       # vendored as-is
    │   ├── agy/config.yaml            # vendored as-is
    │   └── pi/config.yaml             # vendored as-is
    └── skills/
        ├── investigate/SKILL.md       # vendored as-is
        ├── fanout/SKILL.md            # vendored as-is
        └── cross-review/SKILL.md      # HAS a delta, see below
```

Everything under `agents/` and the `investigate` / `fanout` skills are
unmodified copies of upstream Polly. Only two files carry deltas, and each
delta is documented inline as a comment at the point of change — this README
points at them rather than duplicating their content (so they can't drift out
of sync):

- **`polly/config.yaml`** — the `guardrails.policies.cost_budget` block near
  the end of the file. See the `# dev-infrastructure delta` comment directly
  above that block for what it does and why.
- **`polly/skills/cross-review/SKILL.md`** — see the comment block at the top
  of the file, which names Procedure step 3 and the entire "Standing review
  dimensions" section as the only changes from upstream.

Both deltas are explained in more depth, with their rationale, in
`specs/omnigent-setup.md` (see "Codex is a required reviewer, not
opportunistic" and the Rollout Phase cost-cap decision).

## Re-vendoring after an `omnigent upgrade`

The source of truth upstream is the installed `omnigent` package's bundled
Polly example, not a GitHub checkout. Find it by invoking the **uv tool's own
venv Python**, not the ambient `python3` on `PATH`:

```bash
~/.local/share/uv/tools/omnigent/bin/python3 -c "import omnigent, os; print(os.path.join(os.path.dirname(omnigent.__file__), 'resources', 'examples', 'polly'))"
```

This has to be that specific interpreter: running plain `python3 -c "import
omnigent; ..."` from this repo's root resolves `omnigent` to *this repo's own
top-level `omnigent/` directory* as a namespace package (no `__init__.py`
needed), shadowing the real installed package and returning `None` /
`TypeError` instead of a real path. The uv-tool venv doesn't have that
shadowing problem, since this repo isn't on its `sys.path`.

On this machine (via `uv tool install omnigent`), that command resolves to:

```
~/.local/share/uv/tools/omnigent/lib/python3.12/site-packages/omnigent/resources/examples/polly/
```

To re-sync after an `omnigent upgrade`:

1. Diff the new package's `resources/examples/polly/` against this directory's
   `omnigent/polly/`, again using the uv-tool venv's own Python:
   ```bash
   diff -ru "$(~/.local/share/uv/tools/omnigent/bin/python3 -c "import omnigent, os; print(os.path.join(os.path.dirname(omnigent.__file__), 'resources', 'examples', 'polly'))")" omnigent/polly/
   ```
2. Pull in any upstream changes (new/changed agents, new skills, changed
   defaults), being careful to preserve — or re-apply — the two documented
   deltas on top:
   - Re-add the `cost_budget` policy block to `config.yaml` if upstream
     touched the `guardrails.policies` section.
   - Re-apply the Codex-pinning changes to `cross-review/SKILL.md` (the
     header comment, Procedure step 3, and the "Standing review dimensions"
     section) if upstream changed that skill.
3. Confirm both delta comments are still present and accurate after the
   merge — they're what future readers (human or agent) rely on to know
   these aren't upstream bugs.

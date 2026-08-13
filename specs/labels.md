# Label Glossary

Canonical GitHub label definitions for all workflow-compatible repos. This is the single source of truth — other repos (`fieldkit`, the future W3 deploy repo) reference this doc rather than keeping their own copy. See [github-task-workflow.md](github-task-workflow.md) for how these are used.

| Label | Meaning | Type |
|---|---|---|
| `agent-ready` | Fully specified and approved; a worker agent may claim it | workflow state |
| `needs-approval` | Awaiting a human decision (issue breakdown, or a PR pending review) | workflow state |
| `spec` | Deliverable is a specification document | work type |
| `code` | Deliverable is a code change | work type |
| `docs` | Deliverable is documentation | work type |
| `content` | Deliverable is external content (e.g. a LinkedIn article) | work type |

## Conventions

- Every issue gets exactly one work-type label (`spec` / `code` / `docs` / `content`) plus whichever workflow-state label reflects where it currently sits.
- New labels are proposed here first (spec-first) before being created on GitHub, so the glossary never drifts out of sync with what's actually in use.
- Labels are created identically (same name, color, description) across every workflow-compatible repo.

# Architecture Decision Records

Why the configuration looks the way it does. `docs/architecture.md` describes the current shape;
these records describe the decisions that produced it, the alternatives that were rejected, and
what each choice costs.

Conventions:

- One decision per file, named `NNNN-kebab-case-title.md`, numbered monotonically.
- Accepted records are not rewritten. If a decision is replaced, add a new record and mark the
  old one `superseded by NNNN`.
- Keep each record short. Link to supporting material rather than pasting it.

| # | Title | Status |
| --- | --- | --- |
| [0001](0001-zsh-startup-fpath-and-path-policy.md) | zsh startup: fpath normalization and PATH precedence | accepted |

## Workflow
- Restate the task before starting; ask when ambiguous. Prefer small, reviewable changes over large ones.
- Run the project's formatter, linter, and tests before declaring work done. Report failures verbatim; never claim success you did not verify.
- One logical change per commit. Imperative subject under 50 characters; body explains *why*. Never commit secrets, build artifacts, or unrelated changes.
- Never rewrite shared history or run destructive git commands (`push --force`, `reset --hard`, `clean -f`) without explicit approval.

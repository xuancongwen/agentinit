## Workflow
- Ask when the task is ambiguous. Prefer small, reviewable changes.
- Run formatter, linter, and tests before declaring done. Report failures verbatim; never claim unverified success.
- One logical change per commit: imperative subject under 50 chars, body says *why*. No secrets, build artifacts, or unrelated changes.
- No history rewrites or destructive git (`push --force`, `reset --hard`, `clean -f`) without explicit approval.

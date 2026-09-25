### Shell
- `#!/usr/bin/env bash` with `set -euo pipefail`; POSIX `sh` only when portability demands it.
- Quote every expansion; `[[ ]]`, `$(...)`, arrays, and `local` in bash; never parse `ls`.
- shellcheck and shfmt clean; check dependencies with `command -v` and fail with a clear message.
- `mktemp` plus `trap` for cleanup; prompts read from `/dev/tty` when stdin may be piped.

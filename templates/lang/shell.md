### Shell
- `#!/usr/bin/env bash`, `set -euo pipefail`; POSIX `sh` only when portability demands.
- Quote every expansion; `[[ ]]`, `$(...)`, arrays, `local`; never parse `ls`.
- shellcheck and shfmt clean; check dependencies with `command -v`.
- `mktemp` with `trap` cleanup; read prompts from `/dev/tty` when stdin may be piped.

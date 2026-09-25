#!/usr/bin/env bash
# Usage: test/run.sh [script]   (defaults to the built install.sh)
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
script="${1:-$root/install.sh}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
n=0
ok() { n=$((n + 1)); }
fail() { echo "FAIL: $*" >&2; exit 1; }
has() { grep -q -- "$2" "$1" || fail "$3"; ok; }
lacks() { ! grep -q -- "$2" "$1" || fail "$3"; ok; }
run() { bash "$script" "$@" </dev/null 2>"$tmp/log" || { cat "$tmp/log" >&2; fail "aipair exited non-zero: $*"; }; }

# Fresh project with auto-detection
p="$tmp/p1"; mkdir -p "$p/src" "$p/node_modules/x"
touch "$p/go.mod" "$p/src/main.py" "$p/node_modules/x/index.js"
run -y -C "$p" --attribution no --branches yes --default-branch main
has "$p/AGENTS.md" '^### Go' "Go detected"
has "$p/AGENTS.md" '^### Python' "Python detected"
lacks "$p/AGENTS.md" '^### JavaScript' "node_modules pruned"
has "$p/AGENTS.md" 'No AI attribution' "attribution off"
has "$p/AGENTS.md" 'PR for every merge into `main`' "branch workflow"
has "$p/CLAUDE.md" '^@AGENTS.md$' "CLAUDE.md imports AGENTS.md"
has "$p/GEMINI.md" 'AGENTS.md' "GEMINI.md points at AGENTS.md"

# Re-run: user edits survive, options change, markers stay unique
sed -i.bak 's/Purpose: TODO/Purpose: Widgets/' "$p/AGENTS.md" && rm "$p/AGENTS.md.bak"
echo "- Trailing custom note" >>"$p/AGENTS.md"
run -y -C "$p" --attribution yes --branches no --langs rust,shell
has "$p/AGENTS.md" 'Purpose: Widgets' "Project edit preserved"
has "$p/AGENTS.md" 'Trailing custom note' "content after end marker preserved"
has "$p/AGENTS.md" 'Co-Authored-By' "attribution on"
has "$p/AGENTS.md" 'no branches or PRs unless asked' "branch workflow off"
has "$p/AGENTS.md" '^### Rust' "explicit langs applied"
lacks "$p/AGENTS.md" '^### Go' "old langs removed"
[ "$(grep -c 'aipair:begin' "$p/AGENTS.md")" = 1 ] || fail "duplicate begin marker"; ok
[ "$(grep -c 'aipair:end' "$p/AGENTS.md")" = 1 ] || fail "duplicate end marker"; ok

# Existing files: foreign AGENTS.md is appended to, foreign pointers are left alone
p="$tmp/p2"; mkdir -p "$p"
printf '# Mine\n\nKeep this.\n' >"$p/AGENTS.md"
printf 'my own claude rules\n' >"$p/CLAUDE.md"
run -y -C "$p" --langs none
has "$p/AGENTS.md" '^# Mine' "foreign AGENTS.md kept"
has "$p/AGENTS.md" 'aipair:begin' "block appended"
lacks "$p/AGENTS.md" '^## Languages' "no languages section when none"
has "$p/CLAUDE.md" 'my own claude rules' "foreign CLAUDE.md untouched"
lacks "$p/CLAUDE.md" '@AGENTS.md' "foreign CLAUDE.md not overwritten"
run -y -C "$p" --langs none --force
has "$p/CLAUDE.md" '^@AGENTS.md$' "--force overwrites"
has "$p/CLAUDE.md.bak" 'my own claude rules' "--force backs up"

# --stdout writes nothing; default branch falls back to master outside git
p="$tmp/p3"; mkdir -p "$p"
bash "$script" -y -C "$p" --langs c --stdout </dev/null >"$tmp/out"
[ ! -e "$p/AGENTS.md" ] || fail "--stdout wrote a file"; ok
has "$tmp/out" '^### C$' "--stdout prints C section"
has "$tmp/out" 'merge into `master`' "default branch is master"

# Default branch is detected from an existing git repo
p="$tmp/p4"; mkdir -p "$p"; git -C "$p" init -q -b trunk
git -C "$p" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
bash "$script" -y -C "$p" --langs none --stdout </dev/null >"$tmp/out"
has "$tmp/out" 'merge into `trunk`' "default branch detected from git"

# Every language id renders a heading
for id in $(bash "$script" --list-langs); do
  out=$(bash "$script" -y -C "$p" --langs "$id" --stdout </dev/null)
  printf '%s\n' "$out" | grep -q '^### ' || fail "lang $id renders"
done; ok

# Bad input fails
! bash "$script" -y -C "$p" --langs cobol </dev/null 2>/dev/null || fail "unknown lang accepted"; ok
! bash "$script" -y -C "$p" --attribution maybe </dev/null 2>/dev/null || fail "bad yes/no accepted"; ok

echo "ok: $n checks passed ($script)"

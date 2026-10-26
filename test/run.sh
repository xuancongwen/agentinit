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
run() { bash "$script" "$@" </dev/null 2>"$tmp/log" || { cat "$tmp/log" >&2; fail "agentinit exited non-zero: $*"; }; }

# Fresh project with auto-detection
p="$tmp/p1"; mkdir -p "$p/src" "$p/node_modules/x"
touch "$p/go.mod" "$p/src/main.py" "$p/node_modules/x/index.js"
run -y -C "$p" --attribution no --mode iterate --default-branch main
has "$p/AGENTS.md" '^### Go' "Go detected"
has "$p/AGENTS.md" '^### Python' "Python detected"
lacks "$p/AGENTS.md" '^### JavaScript' "node_modules pruned"
has "$p/AGENTS.md" 'No AI attribution' "attribution off"
has "$p/AGENTS.md" 'PR into `main`' "iterate mode opens PRs"
has "$p/AGENTS.md" 'git worktree add .worktrees/' "worktree per task, inside the project"
has "$p/AGENTS.md" 'never `git checkout -b`' "branches only via worktrees"
has "$p/AGENTS.md" 'main checkout is the user' "main checkout off limits"
has "$p/AGENTS.md" 'agentinit:settings mode=iterate; attribution=no; default-branch=main;' "settings saved"
has "$p/.gitignore" '^\.worktrees/$' "worktrees ignored"
has "$p/.gitignore" '^\.claude/worktrees/$' "Claude Code worktrees ignored"
has "$p/.claude/settings.json" '"commit": ""' "Claude Code commit attribution off"
has "$p/.claude/settings.json" '"pr": ""' "Claude Code PR attribution off"
has "$p/AGENTS.md" 'GitHub issue' "tracker defaults to GitHub issues"
has "$p/CLAUDE.md" '^@AGENTS.md$' "CLAUDE.md imports AGENTS.md"
has "$p/GEMINI.md" 'AGENTS.md' "GEMINI.md points at AGENTS.md"

# Re-run: user edits survive, options change, markers stay unique
sed -i.bak 's/Purpose: TODO/Purpose: Widgets/' "$p/AGENTS.md" && rm "$p/AGENTS.md.bak"
echo "- Trailing custom note" >>"$p/AGENTS.md"
run -y -C "$p" --langs none
[ "$(grep -c 'worktrees/$' "$p/.gitignore")" = 2 ] || fail "gitignore entries duplicated"; ok
run -y -C "$p" --attribution yes --mode build --langs rust,shell
has "$p/AGENTS.md" 'Purpose: Widgets' "Project edit preserved"
has "$p/AGENTS.md" 'Trailing custom note' "content after end marker preserved"
has "$p/AGENTS.md" 'Co-Authored-By' "attribution on"
has "$p/AGENTS.md" 'commit finished work straight to it' "build mode commits directly"
has "$p/AGENTS.md" 'on `main`' "saved default branch reused"
lacks "$p/AGENTS.md" 'PR into' "build mode drops PRs"
has "$p/AGENTS.md" '^### Rust' "explicit langs applied"
lacks "$p/AGENTS.md" '^### Go' "old langs removed"
lacks "$p/AGENTS.md" 'git worktree' "build mode drops worktrees"
if command -v jq >/dev/null; then
  [ ! -e "$p/.claude/settings.json" ] || fail "attribution override removed"; ok
fi
[ "$(grep -c 'agentinit:begin' "$p/AGENTS.md")" = 1 ] || fail "duplicate begin marker"; ok
[ "$(grep -c 'agentinit:end' "$p/AGENTS.md")" = 1 ] || fail "duplicate end marker"; ok

# Toggling the mode alone keeps every other saved setting
run -C "$p" --mode iterate
has "$p/AGENTS.md" 'agentinit:settings mode=iterate; attribution=yes; default-branch=main; tracker=github; langs=rust,shell' "toggle keeps settings"
has "$p/AGENTS.md" 'PR into `main`' "toggled to iterate"
has "$p/AGENTS.md" '^### Rust' "toggle keeps langs"
run -C "$p" --mode build
has "$p/AGENTS.md" 'mode=build; attribution=yes' "toggled back to build"

# Existing Claude Code settings are merged, not replaced
if command -v jq >/dev/null; then
  p="$tmp/p8"; mkdir -p "$p/.claude"
  printf '{"model": "opus", "attribution": {"commit": "Co-Authored-By: x"}}\n' >"$p/.claude/settings.json"
  run -y -C "$p" --langs none --attribution no
  [ "$(jq -c . "$p/.claude/settings.json")" = '{"model":"opus","attribution":{"commit":"","pr":""}}' ] ||
    fail "settings.json merged"; ok
  run -y -C "$p" --langs none --attribution yes
  [ "$(jq -c . "$p/.claude/settings.json")" = '{"model":"opus"}' ] || fail "attribution override removed, rest kept"; ok
fi

# Existing files: foreign AGENTS.md is appended to, foreign pointers are left alone
p="$tmp/p2"; mkdir -p "$p"
printf '# Mine\n\nKeep this.\n' >"$p/AGENTS.md"
printf 'my own claude rules\n' >"$p/CLAUDE.md"
run -y -C "$p" --langs none
has "$p/AGENTS.md" '^# Mine' "foreign AGENTS.md kept"
has "$p/AGENTS.md" 'agentinit:begin' "block appended"
lacks "$p/AGENTS.md" '^## Languages' "no languages section when none"
has "$p/CLAUDE.md" 'my own claude rules' "foreign CLAUDE.md untouched"
lacks "$p/CLAUDE.md" '@AGENTS.md' "foreign CLAUDE.md not overwritten"
run -y -C "$p" --langs none --force
has "$p/CLAUDE.md" '^@AGENTS.md$' "--force overwrites"
has "$p/CLAUDE.md.bak" 'my own claude rules' "--force backs up"

# Symlinked pointers are respected and never written through
p="$tmp/p6"; mkdir -p "$p"; ln -s AGENTS.md "$p/CLAUDE.md"; ln -s AGENTS.md "$p/GEMINI.md"
run -y -C "$p" --langs none --force
[ -L "$p/CLAUDE.md" ] || fail "CLAUDE.md symlink kept"; ok
has "$p/AGENTS.md" 'agentinit:begin' "AGENTS.md not overwritten through symlink"
p="$tmp/p7"; mkdir -p "$p"; echo 'other rules' >"$p/OTHER.md"; ln -s OTHER.md "$p/CLAUDE.md"
run -y -C "$p" --langs none --force
[ ! -L "$p/CLAUDE.md" ] || fail "foreign symlink replaced"; ok
has "$p/OTHER.md" 'other rules' "--force does not write through foreign symlink"

# --stdout writes nothing; default branch falls back to master outside git
p="$tmp/p3"; mkdir -p "$p"
bash "$script" -y -C "$p" --langs c --stdout </dev/null >"$tmp/out"
[ ! -e "$p/AGENTS.md" ] || fail "--stdout wrote a file"; ok
has "$tmp/out" '^### C$' "--stdout prints C section"
has "$tmp/out" 'PR into `master`' "default branch is master"

# Default branch is detected from an existing git repo
p="$tmp/p4"; mkdir -p "$p"; git -C "$p" init -q -b trunk
git -C "$p" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
bash "$script" -y -C "$p" --langs none --stdout </dev/null >"$tmp/out"
has "$tmp/out" 'PR into `trunk`' "default branch detected from git"

# Build mode commits straight to the default branch in the main checkout
bash "$script" -y -C "$p" --mode build --langs none --stdout </dev/null >"$tmp/out"
has "$tmp/out" 'main checkout on `trunk`' "build mode targets default branch"
lacks "$tmp/out" 'Never commit to' "build mode drops PR rule"
lacks "$tmp/out" 'worktree add' "build mode drops worktrees"

# Tracker: a custom MCP-backed tracker by name, or none
bash "$script" -y -C "$p" --tracker Trackstar --langs none --stdout </dev/null >"$tmp/out"
has "$tmp/out" 'in Trackstar via its MCP' "custom tracker named"
lacks "$tmp/out" 'GitHub issue' "custom tracker replaces GitHub"
bash "$script" -y -C "$p" --tracker none --langs none --stdout </dev/null >"$tmp/out"
lacks "$tmp/out" '## Task tracking' "tracker none omits section"
! bash "$script" -y -C "$p" --tracker 'a|b' --stdout </dev/null >/dev/null 2>&1 || fail "invalid tracker name accepted"; ok

# Cursor and Windsurf rule files that load alongside AGENTS.md are flagged
p="$tmp/p5"; mkdir -p "$p/.cursor/rules" "$p/.windsurf/rules"
touch "$p/.cursorrules" "$p/.windsurfrules"
run -y -C "$p" --langs none
for f in .cursorrules .cursor/rules .windsurfrules .windsurf/rules; do
  has "$tmp/log" "$f also loads alongside AGENTS.md" "$f flagged"
done
lacks "$tmp/log" '.devin/rules' "absent rule dirs not flagged"
lacks "$tmp/log" '12,000' "short AGENTS.md not flagged"
printf '%12001s\n' x >>"$p/AGENTS.md"
run -y -C "$p" --langs none
has "$tmp/log" 'exceeds 12,000 characters' "oversized AGENTS.md flagged"

# Every language id renders a heading
for id in $(bash "$script" --list-langs); do
  out=$(bash "$script" -y -C "$p" --langs "$id" --stdout </dev/null)
  printf '%s\n' "$out" | grep -q '^### ' || fail "lang $id renders"
done; ok

# Bad input fails
! bash "$script" -y -C "$p" --langs cobol </dev/null 2>/dev/null || fail "unknown lang accepted"; ok
! bash "$script" -y -C "$p" --attribution maybe </dev/null 2>/dev/null || fail "bad yes/no accepted"; ok
! bash "$script" -y -C "$p" --mode maybe </dev/null 2>/dev/null || fail "bad mode accepted"; ok

echo "ok: $n checks passed ($script)"

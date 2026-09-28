#!/usr/bin/env bash
# agentinit: generate AGENTS.md (single source of truth for AI coding agents)
# plus CLAUDE.md and GEMINI.md pointers that defer to it.
#
#   curl -fsSL https://raw.githubusercontent.com/xuancongwen/agentinit/master/install.sh | bash
#
# Re-running replaces only the block between the agentinit markers in AGENTS.md.
set -euo pipefail

AGENTINIT_VERSION="0.1.0"
BEGIN_MARK='<!-- agentinit:begin'
END_MARK='<!-- agentinit:end -->'

# id|Display name|file patterns that mark a project as using the language
LANG_TABLE='
c|C|*.c
cpp|C++|*.cpp *.cc *.cxx *.hpp CMakeLists.txt
rust|Rust|Cargo.toml *.rs
go|Go|go.mod *.go
ruby|Ruby|Gemfile *.rb
python|Python|pyproject.toml requirements.txt setup.py *.py
javascript|JavaScript|package.json *.js *.jsx *.mjs *.cjs
typescript|TypeScript|tsconfig.json *.ts *.tsx
swift|Swift|Package.swift *.swift
objective-c|Objective-C|*.m *.mm
java|Java|pom.xml build.gradle *.java
kotlin|Kotlin|build.gradle.kts *.kt *.kts
csharp|C#|*.csproj *.sln *.cs
php|PHP|composer.json *.php
shell|Shell|*.sh *.bash
sql|SQL|*.sql
dart|Dart|pubspec.yaml *.dart
elixir|Elixir|mix.exs *.ex *.exs
'
PRUNE_DIRS='.git node_modules vendor target build dist out .venv venv __pycache__ Pods DerivedData'

TARGET="."
ASSUME_YES=0
ATTRIBUTION=""
BRANCHES=""
LANGS="auto"
DEFAULT_BRANCH=""
FORCE=0
STDOUT=0

usage() {
  cat <<USAGE
agentinit v$AGENTINIT_VERSION - generate AGENTS.md, CLAUDE.md, and GEMINI.md for a project.

Usage: agentinit [options]

  -C, --dir DIR             project directory (default: .)
  -y, --yes                 non-interactive; use flags and defaults
      --attribution yes|no  keep AI attribution in commits (default: no)
      --branches MODE       yes: branch per task, PR before every merge (default)
                            early: commit and push straight to the default branch
                            no: commit on the current branch, no PRs
      --default-branch NAME default branch name (default: detected, else master)
      --langs LIST          comma-separated language ids, "auto" (default), or "none"
      --list-langs          print supported language ids and exit
      --stdout              print the generated AGENTS.md and write nothing
      --force               overwrite foreign CLAUDE.md/GEMINI.md (backs up to *.bak)
  -h, --help                show this help
  -V, --version             show version

Prompts read from the terminal even when piped through curl; pass -y to skip them.
USAGE
}

log() { printf 'agentinit: %s\n' "$*" >&2; }
die() { log "$*"; exit 1; }

# --- templates ---------------------------------------------------------------
# Development mode reads ./templates; build.sh replaces this region with the
# embedded copies that make install.sh self-contained.
# @@TPL_BEGIN@@
TPL_DIR="${AGENTINIT_TEMPLATES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/templates}"
tpl() { cat "$TPL_DIR/$1.md"; }
# @@TPL_END@@

# --- helpers -----------------------------------------------------------------
yn() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    y|yes|true|1) echo yes ;;
    n|no|false|0) echo no ;;
    *) die "expected yes or no, got '$1'" ;;
  esac
}

branch_mode() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    e|early) echo early ;;
    *) yn "$1" ;;
  esac
}

# ask PROMPT DEFAULT -> prints the answer. Reads /dev/tty when stdin is a pipe.
ask() {
  local reply=""
  if [ "$ASSUME_YES" = 1 ]; then
    printf '%s' "$2"; return
  fi
  if [ -t 0 ]; then
    read -r -p "$1 [$2]: " reply
  elif [ -r /dev/tty ] && [ -w /dev/tty ]; then
    read -r -p "$1 [$2]: " reply </dev/tty
  fi
  printf '%s' "${reply:-$2}"
}

lang_ids() { printf '%s\n' "$LANG_TABLE" | awk -F'|' 'NF { print $1 }'; }
lang_name() { printf '%s\n' "$LANG_TABLE" | awk -F'|' -v id="$1" '$1 == id { print $2 }'; }
lang_patterns() { printf '%s\n' "$LANG_TABLE" | awk -F'|' -v id="$1" '$1 == id { print $3 }'; }

# has_files "pat1 pat2 ..." -> true if any file matching a pattern exists (depth <= 4)
has_files() {
  local prune=() names=() p
  for p in $PRUNE_DIRS; do prune+=(-o -name "$p"); done
  for p in $1; do names+=(-o -name "$p"); done
  [ -n "$(find "$TARGET" -maxdepth 4 \( -false "${prune[@]}" \) -prune \
      -o -type f \( -false "${names[@]}" \) -print 2>/dev/null | head -n 1)" ]
}

detect_langs() {
  local id out=""
  for id in $(lang_ids); do
    has_files "$(lang_patterns "$id")" && out="$out,$id"
  done
  # TypeScript projects always carry package.json; its section covers JavaScript.
  case ",$out," in *,typescript,*) out=$(printf '%s' "$out" | sed 's/,javascript//') ;; esac
  printf '%s' "${out#,}"
}

validate_langs() {
  local id
  for id in $(printf '%s' "$1" | tr ',' ' '); do
    [ -n "$(lang_name "$id")" ] || die "unknown language '$id' (see --list-langs)"
  done
}

detect_default_branch() {
  local b
  b=$(git -C "$TARGET" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || true)
  if [ -n "$b" ]; then printf '%s' "${b#origin/}"; return; fi
  for b in master main trunk; do
    if git -C "$TARGET" show-ref --verify --quiet "refs/heads/$b" 2>/dev/null; then
      printf '%s' "$b"; return
    fi
  done
  printf 'master'
}

# --- generation --------------------------------------------------------------
managed_block() {
  local id
  printf '%s v%s. Re-running agentinit replaces this block; edit outside the markers. -->\n' \
    "$BEGIN_MARK" "$AGENTINIT_VERSION"
  tpl workflow
  tpl "branches-$BRANCHES" | sed "s|{{DEFAULT_BRANCH}}|$DEFAULT_BRANCH|g"
  tpl "attribution-$ATTRIBUTION"
  printf '\n'
  tpl code
  if [ "$LANGS" != none ] && [ -n "$LANGS" ]; then
    printf '\n## Languages\n'
    for id in $(printf '%s' "$LANGS" | tr ',' ' '); do
      printf '\n'
      tpl "lang/$id"
    done
  fi
  printf '%s\n' "$END_MARK"
}

write_agents() {
  local f="$TARGET/AGENTS.md" tmp block
  block=$(managed_block)
  tmp=$(mktemp "$TARGET/.AGENTS.md.XXXXXX")
  if [ -f "$f" ] && grep -q "$BEGIN_MARK" "$f" && grep -q "$END_MARK" "$f"; then
    local b e
    b=$(grep -n "$BEGIN_MARK" "$f" | head -n 1 | cut -d: -f1)
    e=$(grep -n "$END_MARK" "$f" | tail -n 1 | cut -d: -f1)
    { head -n "$((b - 1))" "$f"; printf '%s\n' "$block"; tail -n "+$((e + 1))" "$f"; } >"$tmp"
    log "updated managed block in AGENTS.md"
  elif [ -f "$f" ]; then
    { cat "$f"; printf '\n%s\n' "$block"; } >"$tmp"
    log "appended managed block to existing AGENTS.md"
  else
    { tpl head; printf '%s\n' "$block"; } >"$tmp"
    log "created AGENTS.md"
  fi
  mv "$tmp" "$f"
}

# write_pointer FILE TEMPLATE OWNERSHIP_PATTERN HINT
write_pointer() {
  local f="$TARGET/$1"
  if [ -L "$f" ] && [ "$(readlink "$f")" = AGENTS.md ]; then
    log "$1 is a symlink to AGENTS.md"; return
  fi
  if [ -f "$f" ]; then
    if grep -q "$3" "$f"; then
      log "$1 already defers to AGENTS.md"; return
    fi
    if [ "$FORCE" = 1 ]; then
      # rm first so a symlinked file is replaced, not written through.
      cp "$f" "$f.bak"; rm -f "$f"; log "backed up $1 to $1.bak"
    else
      log "$1 exists and does not reference AGENTS.md; add '$4' to it or re-run with --force"
      return
    fi
  fi
  tpl "$2" >"$f"
  log "created $1"
}

# Cursor and Windsurf read AGENTS.md natively; their own rule files load
# alongside it, so point out any that could contradict it.
check_other_rules() {
  local f
  for f in .cursorrules .cursor/rules .windsurfrules .windsurf/rules .devin/rules; do
    [ -e "$TARGET/$f" ] && log "$f also loads alongside AGENTS.md; move its rules into AGENTS.md (outside the markers) or remove it"
  done
  # Windsurf truncates any single rule file, AGENTS.md included, past 12,000 characters.
  if [ "$(wc -c <"$TARGET/AGENTS.md")" -gt 12000 ]; then
    log "AGENTS.md exceeds 12,000 characters; Windsurf truncates it"
  fi
  return 0
}

# --- main --------------------------------------------------------------------
need_arg() { [ $# -ge 2 ] || die "$1 requires a value"; }
while [ $# -gt 0 ]; do
  case "$1" in
    -C|--dir) need_arg "$@"; TARGET="$2"; shift ;;
    -y|--yes) ASSUME_YES=1 ;;
    --attribution) need_arg "$@"; ATTRIBUTION=$(yn "$2"); shift ;;
    --attribution=*) ATTRIBUTION=$(yn "${1#*=}") ;;
    --branches) need_arg "$@"; BRANCHES=$(branch_mode "$2"); shift ;;
    --branches=*) BRANCHES=$(branch_mode "${1#*=}") ;;
    --default-branch) need_arg "$@"; DEFAULT_BRANCH="$2"; shift ;;
    --default-branch=*) DEFAULT_BRANCH="${1#*=}" ;;
    --langs) need_arg "$@"; LANGS="$2"; shift ;;
    --langs=*) LANGS="${1#*=}" ;;
    --list-langs) lang_ids; exit 0 ;;
    --stdout) STDOUT=1 ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    -V|--version) echo "agentinit $AGENTINIT_VERSION"; exit 0 ;;
    *) die "unknown option '$1' (try --help)" ;;
  esac
  shift
done

[ -d "$TARGET" ] || die "not a directory: $TARGET"
[ "$STDOUT" = 1 ] || log "v$AGENTINIT_VERSION in $(cd "$TARGET" && pwd)"

[ -n "$ATTRIBUTION" ] || ATTRIBUTION=$(yn "$(ask "Keep AI attribution (Co-Authored-By) in commits? (y/n)" no)")
[ -n "$BRANCHES" ] || BRANCHES=$(branch_mode "$(ask "Branch workflow: yes (branch + PR per task), early (push straight to the default branch during initial development), no (current branch only)" yes)")
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(detect_default_branch)
  [ "$BRANCHES" = no ] || DEFAULT_BRANCH=$(ask "Default branch" "$DEFAULT_BRANCH")
fi
if [ "$LANGS" = auto ]; then
  LANGS=$(detect_langs)
  LANGS=$(ask "Languages (comma-separated ids, 'none' to skip; --list-langs for all)" "${LANGS:-none}")
fi
LANGS=$(printf '%s' "$LANGS" | tr -d ' ')
[ "$LANGS" = none ] || validate_langs "$LANGS"

if [ "$STDOUT" = 1 ]; then
  tpl head
  managed_block
  exit 0
fi

write_agents
write_pointer CLAUDE.md pointer-claude '^@AGENTS\.md' '@AGENTS.md'
write_pointer GEMINI.md pointer-gemini 'AGENTS\.md' 'Read and follow AGENTS.md'
check_other_rules
log "done. Fill in the Project section of AGENTS.md; it is what agents read first."

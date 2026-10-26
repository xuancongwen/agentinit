#!/usr/bin/env bash
# agentinit: generate AGENTS.md (single source of truth for AI coding agents)
# plus CLAUDE.md and GEMINI.md pointers that defer to it.
#
#   curl -fsSL https://raw.githubusercontent.com/xuancongwen/agentinit/master/install.sh | bash
#
# Re-running replaces only the block between the agentinit markers in AGENTS.md.
set -euo pipefail

AGENTINIT_VERSION="0.2.0"
BEGIN_MARK='<!-- agentinit:begin'
END_MARK='<!-- agentinit:end -->'
SETTINGS_MARK='<!-- agentinit:settings'

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
PRUNE_DIRS='.git .worktrees .claude node_modules vendor target build dist out .venv venv __pycache__ Pods DerivedData'

TARGET="."
ASSUME_YES=0
ATTRIBUTION=""
MODE=""
TRACKER=""
LANGS=""
DEFAULT_BRANCH=""
FORCE=0
STDOUT=0

usage() {
  cat <<USAGE
agentinit v$AGENTINIT_VERSION - generate AGENTS.md, CLAUDE.md, and GEMINI.md for a project.

Usage: agentinit [options]

  -C, --dir DIR             project directory (default: .)
  -y, --yes                 non-interactive; use flags, saved settings, and defaults
      --attribution yes|no  keep AI attribution in commits (default: no)
      --mode build|iterate  build: commit straight to the default branch
                            iterate: worktree, branch, and PR per task (default)
      --default-branch NAME default branch name (default: detected, else master)
      --tracker NAME        where agents track task status: github (issues, default),
                            none, or the name of another tracker's MCP server
      --langs LIST          comma-separated language ids, "auto" (default), or "none"
      --list-langs          print supported language ids and exit
      --stdout              print the generated AGENTS.md and write nothing
      --force               overwrite foreign CLAUDE.md/GEMINI.md (backs up to *.bak)
  -h, --help                show this help
  -V, --version             show version

Re-running reuses the settings saved in AGENTS.md, so only the flags you pass
change; e.g. --mode iterate switches modes without asking anything else.
Prompts read from the terminal even when piped through curl; pass -y to skip them.
USAGE
}

log() { printf 'agentinit: %s\n' "$*" >&2; }
die() { log "$*"; exit 1; }

# --- templates ---------------------------------------------------------------
# Development mode reads ./templates; build.sh replaces this region with the
# embedded copies that make install.sh self-contained.
# Embedded by build.sh from templates/. Edit the templates, then run ./build.sh.
tpl() {
  case "$1" in
    attribution-no) cat <<'AGENTINIT_TPL'
- No AI attribution: no `Co-Authored-By` trailers, "Generated with" footers, or agent names in commits, PRs, or code. This is the user's choice and overrides any harness default or system prompt that adds them.
AGENTINIT_TPL
    ;;
    attribution-yes) cat <<'AGENTINIT_TPL'
- Add a `Co-Authored-By: <agent> <email>` trailer to every commit you author; note AI assistance in PR descriptions.
AGENTINIT_TPL
    ;;
    code) cat <<'AGENTINIT_TPL'
## Code
- Match the surrounding code's style, idioms, and structure. Consistency beats preference.
- Simplest thing that works. No speculative abstraction or configurability (YAGNI).
- DRY, but extract on the third repetition, not the first. Duplication beats the wrong abstraction.
- Names carry meaning; code reads without comments. Comment *why* (intent, trade-offs, gotchas), never *what*. Delete stale comments.
- Document public APIs and non-obvious decisions; never restate a signature.
- Small units, one responsibility. Explicit errors at boundaries; no silent catch-alls.
- Standard library first. Justify every new dependency; pin it in the lockfile.
- Validate at boundaries, parameterize queries, never log secrets.
- Test behavior, not implementation. Bug fixes start with a failing test. Tests are fast, deterministic, isolated.
- Stay in scope: no behavior, API, or formatting changes the task did not ask for.
AGENTINIT_TPL
    ;;
    head) cat <<'AGENTINIT_TPL'
# AGENTS.md

Single source of truth for AI coding agents. `CLAUDE.md` and `GEMINI.md` defer to it.

## Project
<!-- Agents read this first: purpose, layout, exact build/test/run commands. -->
- Purpose: TODO
- Build: `TODO`
- Test: `TODO`
- Run: `TODO`

AGENTINIT_TPL
    ;;
    lang/c) cat <<'AGENTINIT_TPL'
### C
- C11 unless the project says otherwise; `-Wall -Wextra -Werror`, zero warnings.
- Check every return value. One owner per allocation, freed on every path.
- `<stdint.h>` fixed-width ints, `size_t` for sizes, `const` and `static` by default.
- Bounded string functions only (`snprintf`, `strnlen`); never `gets`, `strcpy`, `sprintf`.
- Headers declare, sources define; `#pragma once`. Tests run under `-fsanitize=address,undefined`.
AGENTINIT_TPL
    ;;
    lang/cpp) cat <<'AGENTINIT_TPL'
### C++
- C++17+; RAII everywhere. `unique_ptr` by default, `shared_ptr` only for true shared ownership, no raw `new`/`delete`.
- Core Guidelines: `const`/`constexpr` by default, `explicit` constructors, `override`, rule of zero.
- `std::` algorithms, `string_view`, `span`, `optional`, `variant` over raw pointers and sentinels.
- clang-format and clang-tidy clean; no `using namespace` in headers; sanitizers in CI.
- Tests: GoogleTest or Catch2. Build: CMake presets.
AGENTINIT_TPL
    ;;
    lang/csharp) cat <<'AGENTINIT_TPL'
### C#
- Current LTS .NET; `dotnet format` clean; nullable enabled with all warnings fixed.
- `async` end to end, `Async` suffix, `CancellationToken`; never `.Result` or `.Wait()`.
- Records for data, `IReadOnly*` in public APIs, `using` declarations for `IDisposable`.
- Constructor injection; LINQ for queries, loops for side effects.
- Tests: xUnit with FluentAssertions; `dotnet test` passes.
AGENTINIT_TPL
    ;;
    lang/dart) cat <<'AGENTINIT_TPL'
### Dart
- `dart format` and `dart analyze` clean against `analysis_options.yaml`.
- `final` by default, `const` where possible; no `!` unless proven non-null.
- Flutter: small widgets, no logic in `build`, state via the project's chosen solution.
- Tests: `dart test` / `flutter test`.
AGENTINIT_TPL
    ;;
    lang/elixir) cat <<'AGENTINIT_TPL'
### Elixir
- `mix format` and `mix credo --strict` clean; `@spec` on public functions; Dialyzer passes.
- Pattern match in function heads; `|>` pipelines; `with` for happy paths; `{:ok, _}`/`{:error, _}`.
- Let it crash: supervise instead of defensive `try/rescue`.
- Tests: ExUnit, `async: true` where safe.
AGENTINIT_TPL
    ;;
    lang/go) cat <<'AGENTINIT_TPL'
### Go
- `gofmt`, `go vet`, and `golangci-lint` (if configured) clean.
- Handle every error; wrap with `fmt.Errorf("doing x: %w", err)`; no `panic` outside `main`.
- Accept interfaces, return structs; small interfaces; `context.Context` first.
- No package-level mutable state or `init()`; useful zero values.
- Table-driven tests with `t.Run`; `go test -race ./...` passes.
AGENTINIT_TPL
    ;;
    lang/java) cat <<'AGENTINIT_TPL'
### Java
- Java 17+; Spotless or Checkstyle clean, zero warnings.
- `final` fields, records for data, `Optional` only as a return type.
- Composition over inheritance; unchecked exceptions in new APIs; never swallow one.
- Streams for transforms, loops for side effects; try-with-resources for every `AutoCloseable`.
- Tests: JUnit 5 with AssertJ; `mvn verify` or `gradle check` passes.
AGENTINIT_TPL
    ;;
    lang/javascript) cat <<'AGENTINIT_TPL'
### JavaScript
- ES modules; `const` by default, `let` when reassigned, never `var`; `===` only.
- `async`/`await` over promise chains; every rejection handled.
- Prettier and ESLint clean; respect the package manager and lockfile.
- Tests: Vitest, Jest, or `node:test`; test behavior, not markup.
AGENTINIT_TPL
    ;;
    lang/kotlin) cat <<'AGENTINIT_TPL'
### Kotlin
- ktlint and detekt clean. No `!!`: use `?.`, `?:`, or `requireNotNull` with a message.
- `val` over `var`; data classes, sealed classes for state, exhaustive `when`.
- Structured concurrency; never `GlobalScope`; suspend functions over callbacks.
- Tests: JUnit 5 or Kotest with MockK.
AGENTINIT_TPL
    ;;
    lang/objective-c) cat <<'AGENTINIT_TPL'
### Objective-C
- ARC. Properties `nonatomic`; `copy` for `NSString` and blocks; `weak` for delegates.
- `NS_ASSUME_NONNULL_BEGIN`/`END` in every header; lightweight generics; `instancetype`.
- Literals, dot syntax, `NSError **` for failures; no exceptions for control flow.
- `weakSelf` in escaping blocks; no `+load` side effects. clang-format clean; XCTest.
AGENTINIT_TPL
    ;;
    lang/php) cat <<'AGENTINIT_TPL'
### PHP
- PHP 8.2+, `declare(strict_types=1)`; PSR-12 via PHP-CS-Fixer; PHPStan or Psalm passes.
- Type every parameter, return, and property; readonly properties and enums over constants.
- PSR-4 autoloading; never `@`, `extract()`, or `eval()`.
- Prepared statements only; escape all output. Tests: PHPUnit or Pest.
AGENTINIT_TPL
    ;;
    lang/python) cat <<'AGENTINIT_TPL'
### Python
- `ruff format` and `ruff check` clean; type hints on public functions; pyright or mypy passes.
- `pathlib`, f-strings, dataclasses or pydantic for records, context managers for resources.
- No mutable default arguments, bare `except:`, or wildcard imports.
- Pinned deps in `pyproject.toml` via `uv`, `pip-tools`, or `poetry`.
- Tests: pytest with fixtures and `parametrize`.
AGENTINIT_TPL
    ;;
    lang/ruby) cat <<'AGENTINIT_TPL'
### Ruby
- RuboCop clean; `# frozen_string_literal: true`; `snake_case` methods, `CamelCase` classes.
- `each`/`map`/`select` over `for`; guard clauses over nested `if`; keyword args beyond two parameters.
- Raise specific exceptions; never `rescue Exception`; no core-class monkey patches.
- Bundler with committed `Gemfile.lock`. Tests: RSpec or Minitest, one behavior per example.
AGENTINIT_TPL
    ;;
    lang/rust) cat <<'AGENTINIT_TPL'
### Rust
- `cargo fmt` and `cargo clippy --all-targets -- -D warnings` pass.
- No `unwrap`/`expect` outside tests. Propagate with `?`; `thiserror` in libraries, `anyhow` in binaries.
- Borrow before cloning; `&str`/`&[T]` parameters; iterators over index loops.
- Every `unsafe` block has a `// SAFETY:` comment stating its invariants.
- Unit tests in `#[cfg(test)]`, integration tests in `tests/`, doc examples that compile.
AGENTINIT_TPL
    ;;
    lang/shell) cat <<'AGENTINIT_TPL'
### Shell
- `#!/usr/bin/env bash`, `set -euo pipefail`; POSIX `sh` only when portability demands.
- Quote every expansion; `[[ ]]`, `$(...)`, arrays, `local`; never parse `ls`.
- shellcheck and shfmt clean; check dependencies with `command -v`.
- `mktemp` with `trap` cleanup; read prompts from `/dev/tty` when stdin may be piped.
AGENTINIT_TPL
    ;;
    lang/sql) cat <<'AGENTINIT_TPL'
### SQL
- Uppercase keywords, `snake_case` identifiers, one clause per line, explicit column lists.
- Migrations are forward-only, never edited after merge, idempotent where possible.
- Index what you filter and join on; `EXPLAIN` new queries on large tables.
- Parameterized queries only.
AGENTINIT_TPL
    ;;
    lang/swift) cat <<'AGENTINIT_TPL'
### Swift
- API Design Guidelines; SwiftFormat and SwiftLint clean.
- `let` over `var`; structs and enums by default; protocols over class hierarchies.
- No `!`, `try!`, or `as!` outside tests; use `guard let`, `throws`, `Result`.
- Structured concurrency (`async`/`await`, actors); `@MainActor` for UI.
- Tests: Swift Testing or XCTest; dependencies via SwiftPM.
AGENTINIT_TPL
    ;;
    lang/typescript) cat <<'AGENTINIT_TPL'
### TypeScript
- `strict: true`. No `any` (use `unknown` and narrow); no `!` or `as` without a justifying comment.
- Discriminated unions over optional fields; `readonly` where possible; derive types (`typeof`, `satisfies`, `as const`) rather than duplicate.
- Union literals over enums; export types beside the values they describe.
- Otherwise as JavaScript: ES modules, `const` by default, `async`/`await` with every rejection handled, Prettier and ESLint clean.
AGENTINIT_TPL
    ;;
    mode-build) cat <<'AGENTINIT_TPL'
- Build mode (initial development, one agent at a time): work in the main checkout on `{{DEFAULT_BRANCH}}` and commit finished work straight to it. No worktrees, branches, or PRs, even if your harness defaults to branching first.
AGENTINIT_TPL
    ;;
    mode-iterate) cat <<'AGENTINIT_TPL'
- Iterate mode: every task that changes files gets its own worktree and branch, even a one-line fix, even with no other agent running. The main checkout is the user's and stays on `{{DEFAULT_BRANCH}}`: never edit, commit, or switch branches in it.
- Before the first edit, create the worktree with your harness's worktree tool if it has one (Claude Code: `EnterWorktree`); otherwise run `git worktree add .worktrees/<task> -b <task> {{DEFAULT_BRANCH}}` and `cd` into it. A new branch always means a new worktree, never `git checkout -b` or `git switch` in the main checkout.
- From then on, every path you read, edit, or run is inside the worktree. If `git rev-parse --git-dir` lacks `/worktrees/`, you are in the main checkout: stop and move.
- Never commit to `{{DEFAULT_BRANCH}}`. Push your branch and open a PR into `{{DEFAULT_BRANCH}}`; do not merge it unless told to.
- Never touch another agent's worktree. Once your PR merges, `git worktree remove` yours and delete its branch.
AGENTINIT_TPL
    ;;
    pointer-claude) cat <<'AGENTINIT_TPL'
Edit AGENTS.md, not this file.

@AGENTS.md
AGENTINIT_TPL
    ;;
    pointer-gemini) cat <<'AGENTINIT_TPL'
Follow `AGENTS.md` in this directory; edit it, not this file.
AGENTINIT_TPL
    ;;
    tracker-github) cat <<'AGENTINIT_TPL'
## Task tracking
- Track each task in a GitHub issue (`gh issue` or the GitHub MCP): find or open one, with the goal and how to verify it, before starting.
- Comment as you go, not afterwards: on starting (branch, approach), on plan changes, when blocked and why, and with the PR or commit. The issue alone should show where the work stands.
- Put `Closes #N` in the PR or commit so the issue closes when the work lands, not before.
- If GitHub is unreachable, say so and ask; never skip tracking silently.
AGENTINIT_TPL
    ;;
    tracker-mcp) cat <<'AGENTINIT_TPL'
## Task tracking
- Track each task in {{TRACKER}} via its MCP tools: find or create its ticket, with the goal and how to verify it, before starting.
- Update it as you go, not afterwards: mark it started when you begin, comment on plan changes and blockers, mark it finished when the work lands, and leave acceptance to the user. The ticket alone should show where the work stands.
- Put the ticket ID in branch names, commits, and PRs.
- If {{TRACKER}} is unreachable, say so and ask; never skip tracking silently.
AGENTINIT_TPL
    ;;
    workflow) cat <<'AGENTINIT_TPL'
## Workflow
- Ask when the task is ambiguous. Prefer small, reviewable changes.
- Run formatter, linter, and tests before declaring done. Report failures verbatim; never claim unverified success.
- One logical change per commit: imperative subject under 50 chars, body says *why*. No secrets, build artifacts, or unrelated changes.
- No history rewrites or destructive git (`push --force`, `reset --hard`, `clean -f`) without explicit approval.
AGENTINIT_TPL
    ;;
    *) die "unknown template: $1" ;;
  esac
}

# --- helpers -----------------------------------------------------------------
yn() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    y|yes|true|1) echo yes ;;
    n|no|false|0) echo no ;;
    *) die "expected yes or no, got '$1'" ;;
  esac
}

mode() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    b|build) echo build ;;
    i|iterate) echo iterate ;;
    *) die "expected build or iterate, got '$1'" ;;
  esac
}

# tracker NAME -> github, none, or the name as given for an MCP-backed tracker
tracker() {
  case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    github|gh|github-issues|issues) echo github ;;
    none|no|n|false|0) echo none ;;
    *)
      printf '%s' "$1" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9 ._-]*$' || die "invalid tracker name '$1'"
      printf '%s' "$1" ;;
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

# Fill any setting not given as a flag from the settings line a previous run
# saved in AGENTS.md, so a re-run changes only what it is told to.
load_settings() {
  local f="$TARGET/AGENTS.md" line kv key val kvs=()
  [ -f "$f" ] || return 0
  line=$(sed -n "s/^$SETTINGS_MARK \(.*\) -->\$/\1/p" "$f" | head -n 1)
  if [ -z "$line" ]; then
    grep -q "$BEGIN_MARK" "$f" &&
      log "AGENTS.md predates saved settings; settings without a flag get prompts or defaults this once"
    return 0
  fi
  IFS=';' read -r -a kvs <<<"$line"
  for kv in "${kvs[@]}"; do
    kv=$(printf '%s' "$kv" | sed 's/^ *//; s/ *$//')
    key=${kv%%=*}; val=${kv#*=}
    case "$key" in
      mode) [ -n "$MODE" ] || MODE=$(mode "$val") ;;
      attribution) [ -n "$ATTRIBUTION" ] || ATTRIBUTION=$(yn "$val") ;;
      default-branch) [ -n "$DEFAULT_BRANCH" ] || DEFAULT_BRANCH=$val ;;
      tracker) [ -n "$TRACKER" ] || TRACKER=$(tracker "$val") ;;
      langs) [ -n "$LANGS" ] || LANGS=$val ;;
    esac
  done
  [ "$STDOUT" = 1 ] || log "reusing settings saved in AGENTS.md; flags override them"
}

# --- generation --------------------------------------------------------------
managed_block() {
  local id
  printf '%s v%s. Re-running agentinit replaces this block; edit outside the markers. -->\n' \
    "$BEGIN_MARK" "$AGENTINIT_VERSION"
  printf '%s mode=%s; attribution=%s; default-branch=%s; tracker=%s; langs=%s -->\n' \
    "$SETTINGS_MARK" "$MODE" "$ATTRIBUTION" "$DEFAULT_BRANCH" "$TRACKER" "${LANGS:-none}"
  tpl workflow
  tpl "mode-$MODE" | sed "s|{{DEFAULT_BRANCH}}|$DEFAULT_BRANCH|g"
  tpl "attribution-$ATTRIBUTION"
  printf '\n'
  case "$TRACKER" in
    none) ;;
    github) tpl tracker-github; printf '\n' ;;
    *) tpl tracker-mcp | sed "s|{{TRACKER}}|$TRACKER|g"; printf '\n' ;;
  esac
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

# Iterate mode keeps worktrees inside the project, where agent sandboxes allow
# writes; ignore them so the main checkout stays clean.
ignore_worktrees() {
  local f="$TARGET/.gitignore" dir
  [ "$MODE" = iterate ] || return 0
  # .claude/worktrees is where Claude Code's own worktree tool puts them.
  for dir in .worktrees/ .claude/worktrees/; do
    if [ -f "$f" ]; then
      grep -Fqx -e "$dir" -e "/$dir" -e "${dir%/}" -e "/${dir%/}" "$f" && continue
      [ -z "$(tail -c 1 "$f")" ] || printf '\n' >>"$f"
    fi
    printf '%s\n' "$dir" >>"$f"
    log "added $dir to .gitignore"
  done
}

# Claude Code appends its own Co-Authored-By trailer and PR footer unless its
# settings turn them off; an instruction in AGENTS.md alone does not reliably
# beat that default.
claude_attribution() {
  local f="$TARGET/.claude/settings.json" off='{"commit":"","pr":""}' tmp
  if [ "$ATTRIBUTION" = no ]; then
    if [ ! -e "$f" ]; then
      mkdir -p "$TARGET/.claude"
      printf '{\n  "attribution": {\n    "commit": "",\n    "pr": ""\n  }\n}\n' >"$f"
      log "created .claude/settings.json to turn off Claude Code's attribution"
      return 0
    fi
    if ! command -v jq >/dev/null; then
      grep -q '"attribution"' "$f" ||
        log "add \"attribution\": $off to .claude/settings.json to turn off Claude Code's attribution"
      return 0
    fi
    jq -e --argjson off "$off" '.attribution == $off' "$f" >/dev/null 2>&1 && return 0
    tmp=$(mktemp)
    if jq --argjson off "$off" '.attribution = $off' "$f" >"$tmp" 2>/dev/null; then
      cat "$tmp" >"$f"
      log "turned off Claude Code's attribution in .claude/settings.json"
    else
      log "could not parse .claude/settings.json; add \"attribution\": $off to it"
    fi
    rm -f "$tmp"
  elif [ -f "$f" ] && command -v jq >/dev/null &&
    jq -e --argjson off "$off" '.attribution == $off' "$f" >/dev/null 2>&1; then
    tmp=$(mktemp)
    jq 'del(.attribution)' "$f" >"$tmp"
    if [ "$(jq -c . "$tmp")" = '{}' ]; then
      rm -f "$f"; rmdir "$TARGET/.claude" 2>/dev/null || true
    else
      cat "$tmp" >"$f"
    fi
    rm -f "$tmp"
    log "restored Claude Code's default attribution"
  fi
}

# --- main --------------------------------------------------------------------
need_arg() { [ $# -ge 2 ] || die "$1 requires a value"; }
while [ $# -gt 0 ]; do
  case "$1" in
    -C|--dir) need_arg "$@"; TARGET="$2"; shift ;;
    -y|--yes) ASSUME_YES=1 ;;
    --attribution) need_arg "$@"; ATTRIBUTION=$(yn "$2"); shift ;;
    --attribution=*) ATTRIBUTION=$(yn "${1#*=}") ;;
    --mode) need_arg "$@"; MODE=$(mode "$2"); shift ;;
    --mode=*) MODE=$(mode "${1#*=}") ;;
    --tracker) need_arg "$@"; TRACKER=$(tracker "$2"); shift ;;
    --tracker=*) TRACKER=$(tracker "${1#*=}") ;;
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
load_settings

[ -n "$ATTRIBUTION" ] || ATTRIBUTION=$(yn "$(ask "Keep AI attribution (Co-Authored-By) in commits? (y/n)" no)")
[ -n "$MODE" ] || MODE=$(mode "$(ask "Mode: build (commit straight to the default branch) or iterate (worktree, branch, and PR per task)" iterate)")
[ -n "$DEFAULT_BRANCH" ] || DEFAULT_BRANCH=$(ask "Default branch" "$(detect_default_branch)")
[ -n "$TRACKER" ] || TRACKER=$(tracker "$(ask "Task tracker agents keep updated: github (issues), none, or another tracker's MCP name (e.g. Trackstar)" github)")
if [ -z "$LANGS" ] || [ "$LANGS" = auto ]; then
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
ignore_worktrees
claude_attribution
check_other_rules
log "done. Fill in the Project section of AGENTS.md; it is what agents read first."

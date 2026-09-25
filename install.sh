#!/usr/bin/env bash
# aipair: generate AGENTS.md (single source of truth for AI coding agents)
# plus CLAUDE.md and GEMINI.md pointers that defer to it.
#
#   curl -fsSL https://raw.githubusercontent.com/xuancongwen/aipair/main/install.sh | bash
#
# Re-running replaces only the block between the aipair markers in AGENTS.md.
set -euo pipefail

AIPAIR_VERSION="0.1.0"
BEGIN_MARK='<!-- aipair:begin'
END_MARK='<!-- aipair:end -->'

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
aipair v$AIPAIR_VERSION - generate AGENTS.md, CLAUDE.md, and GEMINI.md for a project.

Usage: aipair [options]

  -C, --dir DIR             project directory (default: .)
  -y, --yes                 non-interactive; use flags and defaults
      --attribution yes|no  keep AI attribution in commits (default: no)
      --branches yes|no     branch per task, PR before every merge (default: yes)
      --default-branch NAME protected branch name (default: detected, else master)
      --langs LIST          comma-separated language ids, "auto" (default), or "none"
      --list-langs          print supported language ids and exit
      --stdout              print the generated AGENTS.md and write nothing
      --force               overwrite foreign CLAUDE.md/GEMINI.md (backs up to *.bak)
  -h, --help                show this help
  -V, --version             show version

Prompts read from the terminal even when piped through curl; pass -y to skip them.
USAGE
}

log() { printf 'aipair: %s\n' "$*" >&2; }
die() { log "$*"; exit 1; }

# --- templates ---------------------------------------------------------------
# Development mode reads ./templates; build.sh replaces this region with the
# embedded copies that make install.sh self-contained.
# Embedded by build.sh from templates/. Edit the templates, then run ./build.sh.
tpl() {
  case "$1" in
    attribution-no) cat <<'AIPAIR_TPL'
- Do not add AI attribution (`Co-Authored-By` trailers, "Generated with" footers, or similar) to commits, PRs, or code.
AIPAIR_TPL
    ;;
    attribution-yes) cat <<'AIPAIR_TPL'
- Attribute your work: add a `Co-Authored-By: <agent name> <agent email>` trailer to every commit you author and note AI assistance in PR descriptions.
AIPAIR_TPL
    ;;
    branches-no) cat <<'AIPAIR_TPL'
- Commit on the current branch. Do not create branches or pull requests unless asked.
AIPAIR_TPL
    ;;
    branches-yes) cat <<'AIPAIR_TPL'
- Never commit directly to `{{DEFAULT_BRANCH}}`. Branch per task (`<type>/<short-slug>`, e.g. `fix/null-config`), open a pull request for every merge into `{{DEFAULT_BRANCH}}`, and do not merge your own PR unless told to.
AIPAIR_TPL
    ;;
    code) cat <<'AIPAIR_TPL'
## Code
- Read the surrounding code first and match its style, idioms, and structure. Consistency beats preference.
- Do the simplest thing that works. No speculative abstractions, options, or flexibility (YAGNI).
- DRY, but extract on the third repetition, not the first. A little duplication beats the wrong abstraction.
- Names carry meaning; code should read without comments. Comment only *why* (intent, trade-offs, gotchas), never *what*. Delete stale comments.
- Document public APIs and non-obvious decisions. Never restate a signature in prose.
- Small units with one responsibility. Explicit, typed errors at boundaries; no silent catch-alls.
- Prefer the standard library. Justify every new dependency and pin it through the lockfile.
- Validate input at boundaries, parameterize queries, and never log secrets or commit credentials.
- Test behavior, not implementation. Every bug fix starts with a failing test. Tests are fast, deterministic, and isolated.
- Stay in scope: do not change behavior, public APIs, or formatting the task did not ask for.
AIPAIR_TPL
    ;;
    head) cat <<'AIPAIR_TPL'
# AGENTS.md

Instructions for AI coding agents. This file is the single source of truth: `CLAUDE.md` and `GEMINI.md` defer to it, and Codex, Antigravity, Grok Build, Cursor, and Copilot read it directly.

## Project
<!-- Agents read this first. Keep it current: purpose, layout, and the exact commands to build, test, and run. -->
- Purpose: TODO
- Build: `TODO`
- Test: `TODO`
- Run: `TODO`

AIPAIR_TPL
    ;;
    lang/c) cat <<'AIPAIR_TPL'
### C
- Use the project's standard (C11 default). Build with `-Wall -Wextra -Werror`; zero warnings.
- Check every return value. Every allocation has exactly one owner and a matching free on all paths.
- Fixed-width ints from `<stdint.h>`, `const` and `static` by default, `size_t` for sizes.
- Bounded string functions only (`snprintf`, `strnlen`); never `gets`, `strcpy`, `sprintf`.
- Headers declare, sources define; include guards or `#pragma once`.
- Run under `-fsanitize=address,undefined` in tests. Frameworks: Unity, cmocka, or Check.
AIPAIR_TPL
    ;;
    lang/cpp) cat <<'AIPAIR_TPL'
### C++
- C++17 or later per project. RAII everywhere; `std::unique_ptr` by default, `shared_ptr` only for real shared ownership, no raw `new`/`delete`.
- Follow the C++ Core Guidelines: `const`/`constexpr` by default, `explicit` single-arg constructors, `override`/`final`, rule of zero.
- Prefer `std::` algorithms, `string_view`, `span`, `optional`, and `variant` over raw pointers and sentinels.
- clang-format and clang-tidy clean; sanitizers in CI; no `using namespace` in headers.
- Tests: GoogleTest or Catch2. Build: CMake with presets.
AIPAIR_TPL
    ;;
    lang/csharp) cat <<'AIPAIR_TPL'
### C#
- Current LTS .NET. `dotnet format` clean; nullable reference types enabled with all warnings fixed.
- `async` end-to-end with `Async` suffix and `CancellationToken`; never `.Result` or `.Wait()`.
- Records for data, `IReadOnly*` collections in public APIs, `using` declarations for `IDisposable`.
- Constructor injection; LINQ for queries, loops for side effects.
- Tests: xUnit with FluentAssertions; `dotnet test` must pass.
AIPAIR_TPL
    ;;
    lang/dart) cat <<'AIPAIR_TPL'
### Dart
- `dart format` and `dart analyze` clean against the project's `analysis_options.yaml`.
- `final` by default, `const` wherever possible; sound null safety with no `!` unless proven.
- Flutter: small widgets, no logic in `build`, state via the project's chosen solution.
- Tests: `dart test` / `flutter test`; widget tests for UI, unit tests for logic.
AIPAIR_TPL
    ;;
    lang/elixir) cat <<'AIPAIR_TPL'
### Elixir
- `mix format` and `mix credo --strict` clean; `@spec` on public functions, Dialyzer passes.
- Pattern match in function heads; `|>` pipelines for transformations; `with` for happy paths; tagged tuples `{:ok, _}`/`{:error, _}`.
- Let it crash: supervise processes instead of defensive `try/rescue`.
- Tests: ExUnit with `async: true` where safe.
AIPAIR_TPL
    ;;
    lang/go) cat <<'AIPAIR_TPL'
### Go
- `gofmt`/`goimports` and `go vet` clean; `golangci-lint` if configured.
- Handle every error; wrap with `fmt.Errorf("doing x: %w", err)`; no `panic` outside `main` and init.
- Accept interfaces, return structs; keep interfaces small; `context.Context` is the first parameter.
- No package-level mutable state; zero values should be useful; avoid `init()`.
- Table-driven tests with `t.Run`; `go test -race ./...` must pass.
AIPAIR_TPL
    ;;
    lang/java) cat <<'AIPAIR_TPL'
### Java
- Java 17+ per project. Formatted and checked by Spotless or Checkstyle; zero warnings.
- Immutability first: `final` fields, records for data, `Optional` only as a return type.
- Interfaces and composition over inheritance; unchecked exceptions in new APIs; never swallow an exception.
- Streams for transformations, loops for side effects; try-with-resources for every `AutoCloseable`.
- Tests: JUnit 5 with AssertJ; `mvn verify` or `gradle check` must pass.
AIPAIR_TPL
    ;;
    lang/javascript) cat <<'AIPAIR_TPL'
### JavaScript
- ES modules; `const` by default, `let` when reassigned, never `var`; strict equality only.
- `async`/`await` over promise chains; every rejection handled; no floating promises.
- Prettier and ESLint clean; respect the project's package manager and lockfile.
- Tests: Vitest, Jest, or `node:test`. Test behavior, not markup.
AIPAIR_TPL
    ;;
    lang/kotlin) cat <<'AIPAIR_TPL'
### Kotlin
- Kotlin coding conventions; ktlint and detekt clean. No `!!`: use `?.`, `?:`, or `requireNotNull` with a message.
- `val` over `var`; data classes for data, sealed classes for state, exhaustive `when`.
- Coroutines with structured concurrency; never `GlobalScope`; suspend functions over callbacks.
- Tests: JUnit 5 or Kotest with MockK.
AIPAIR_TPL
    ;;
    lang/objective-c) cat <<'AIPAIR_TPL'
### Objective-C
- ARC only. Properties `nonatomic`; `copy` for `NSString` and blocks; `weak` for delegates and to break cycles.
- Wrap headers in `NS_ASSUME_NONNULL_BEGIN`/`END`; use lightweight generics and `instancetype`.
- Literals (`@[]`, `@{}`, `@()`), dot syntax for properties, `NSError **` for failures; no exceptions for control flow.
- Capture `weakSelf` in escaping blocks; no `+load` side effects.
- clang-format clean; tests in XCTest.
AIPAIR_TPL
    ;;
    lang/php) cat <<'AIPAIR_TPL'
### PHP
- PHP 8.2+ with `declare(strict_types=1)`; PSR-12 via PHP-CS-Fixer; PHPStan or Psalm at the project's level.
- Type every parameter, return, and property; readonly properties and enums over constants.
- Composer PSR-4 autoloading; never `@` suppression, `extract()`, or `eval()`.
- Prepared statements only; escape all output.
- Tests: PHPUnit or Pest.
AIPAIR_TPL
    ;;
    lang/python) cat <<'AIPAIR_TPL'
### Python
- Python 3.10+ per project. `ruff format` and `ruff check` clean; type hints on all public functions; pyright or mypy passes.
- PEP 8 and PEP 20. `pathlib` over `os.path`, f-strings, dataclasses or pydantic for records, context managers for resources.
- No mutable default arguments; no bare `except:`; no wildcard imports.
- Virtual environment with pinned dependencies (`uv`, `pip-tools`, or `poetry`) declared in `pyproject.toml`.
- Tests: pytest with fixtures and `parametrize`.
AIPAIR_TPL
    ;;
    lang/ruby) cat <<'AIPAIR_TPL'
### Ruby
- Ruby Style Guide via RuboCop; `# frozen_string_literal: true`; 2-space indent, `snake_case` methods, `CamelCase` classes.
- `each`/`map`/`select` over `for`; guard clauses over nested `if`; keyword arguments for more than two parameters.
- Raise specific exceptions; never `rescue Exception`; no monkey-patching core classes.
- Bundler with a committed `Gemfile.lock`.
- Tests: RSpec or Minitest, one behavior per example.
AIPAIR_TPL
    ;;
    lang/rust) cat <<'AIPAIR_TPL'
### Rust
- `cargo fmt` and `cargo clippy --all-targets -- -D warnings` must pass.
- No `unwrap`/`expect` outside tests and provably infallible cases. Propagate with `?`; `thiserror` for libraries, `anyhow` at binaries.
- Borrow before cloning; `&str`/`&[T]` in parameters; iterators over index loops; `impl Trait` over boxing where possible.
- Every `unsafe` block carries a `// SAFETY:` comment stating the upheld invariants.
- Unit tests in `#[cfg(test)]` modules, integration tests in `tests/`, doc examples that compile.
AIPAIR_TPL
    ;;
    lang/shell) cat <<'AIPAIR_TPL'
### Shell
- `#!/usr/bin/env bash` with `set -euo pipefail`; POSIX `sh` only when portability demands it.
- Quote every expansion; `[[ ]]`, `$(...)`, arrays, and `local` in bash; never parse `ls`.
- shellcheck and shfmt clean; check dependencies with `command -v` and fail with a clear message.
- `mktemp` plus `trap` for cleanup; prompts read from `/dev/tty` when stdin may be piped.
AIPAIR_TPL
    ;;
    lang/sql) cat <<'AIPAIR_TPL'
### SQL
- Uppercase keywords, `snake_case` identifiers, one clause per line; explicit column lists, never `SELECT *` in code.
- Migrations are forward-only and never edited after merge; make them idempotent where possible.
- Index what you filter and join on; `EXPLAIN` new queries against large tables.
- Parameterized queries only; never interpolate input.
AIPAIR_TPL
    ;;
    lang/swift) cat <<'AIPAIR_TPL'
### Swift
- Swift API Design Guidelines; SwiftFormat and SwiftLint clean.
- `let` over `var`; structs and enums by default; protocols for abstraction, not class hierarchies.
- No `!`, `try!`, or `as!` outside tests. Use `guard let`, `throws`, and `Result`.
- Structured concurrency (`async`/`await`, actors); `@MainActor` for UI.
- Tests: Swift Testing or XCTest; dependencies via SwiftPM.
AIPAIR_TPL
    ;;
    lang/typescript) cat <<'AIPAIR_TPL'
### TypeScript
- `strict: true`. No `any` (use `unknown` and narrow); no non-null `!` or `as` casts without a justifying comment.
- Discriminated unions over optional fields; `readonly` where possible; derive types (`typeof`, `satisfies`, `as const`) instead of duplicating.
- Export types alongside the values they describe; avoid enums in favor of union literals.
- Otherwise as JavaScript: ES modules, `const` by default, `async`/`await` with every rejection handled, Prettier and ESLint clean.
AIPAIR_TPL
    ;;
    pointer-claude) cat <<'AIPAIR_TPL'
AGENTS.md is the single source of truth for agent instructions in this repo. Edit it, not this file.

@AGENTS.md
AIPAIR_TPL
    ;;
    pointer-gemini) cat <<'AIPAIR_TPL'
Read and follow `AGENTS.md` in this directory. It is the single source of truth for agent instructions; edit it, not this file.
AIPAIR_TPL
    ;;
    workflow) cat <<'AIPAIR_TPL'
## Workflow
- Restate the task before starting; ask when ambiguous. Prefer small, reviewable changes over large ones.
- Run the project's formatter, linter, and tests before declaring work done. Report failures verbatim; never claim success you did not verify.
- One logical change per commit. Imperative subject under 50 characters; body explains *why*. Never commit secrets, build artifacts, or unrelated changes.
- Never rewrite shared history or run destructive git commands (`push --force`, `reset --hard`, `clean -f`) without explicit approval.
AIPAIR_TPL
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
  printf '%s v%s. Re-running aipair replaces only this block; edit outside the markers. -->\n' \
    "$BEGIN_MARK generated by aipair" "$AIPAIR_VERSION"
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
  if [ -f "$f" ]; then
    if grep -q "$3" "$f"; then
      log "$1 already defers to AGENTS.md"; return
    fi
    if [ "$FORCE" = 1 ]; then
      cp "$f" "$f.bak"; log "backed up $1 to $1.bak"
    else
      log "$1 exists and does not reference AGENTS.md; add '$4' to it or re-run with --force"
      return
    fi
  fi
  tpl "$2" >"$f"
  log "created $1"
}

# --- main --------------------------------------------------------------------
need_arg() { [ $# -ge 2 ] || die "$1 requires a value"; }
while [ $# -gt 0 ]; do
  case "$1" in
    -C|--dir) need_arg "$@"; TARGET="$2"; shift ;;
    -y|--yes) ASSUME_YES=1 ;;
    --attribution) need_arg "$@"; ATTRIBUTION=$(yn "$2"); shift ;;
    --attribution=*) ATTRIBUTION=$(yn "${1#*=}") ;;
    --branches) need_arg "$@"; BRANCHES=$(yn "$2"); shift ;;
    --branches=*) BRANCHES=$(yn "${1#*=}") ;;
    --default-branch) need_arg "$@"; DEFAULT_BRANCH="$2"; shift ;;
    --default-branch=*) DEFAULT_BRANCH="${1#*=}" ;;
    --langs) need_arg "$@"; LANGS="$2"; shift ;;
    --langs=*) LANGS="${1#*=}" ;;
    --list-langs) lang_ids; exit 0 ;;
    --stdout) STDOUT=1 ;;
    --force) FORCE=1 ;;
    -h|--help) usage; exit 0 ;;
    -V|--version) echo "aipair $AIPAIR_VERSION"; exit 0 ;;
    *) die "unknown option '$1' (try --help)" ;;
  esac
  shift
done

[ -d "$TARGET" ] || die "not a directory: $TARGET"
[ "$STDOUT" = 1 ] || log "v$AIPAIR_VERSION in $(cd "$TARGET" && pwd)"

[ -n "$ATTRIBUTION" ] || ATTRIBUTION=$(yn "$(ask "Keep AI attribution (Co-Authored-By) in commits? (y/n)" no)")
[ -n "$BRANCHES" ] || BRANCHES=$(yn "$(ask "Work on branches and open a PR before every merge? (y/n)" yes)")
if [ -z "$DEFAULT_BRANCH" ]; then
  DEFAULT_BRANCH=$(detect_default_branch)
  [ "$BRANCHES" = yes ] && DEFAULT_BRANCH=$(ask "Protected default branch" "$DEFAULT_BRANCH")
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
log "done. Fill in the Project section of AGENTS.md; it is what agents read first."

# aipair

One command drops a concise, shared instruction set for AI coding agents into your project.

```sh
curl -fsSL https://raw.githubusercontent.com/xuancongwen/aipair/main/install.sh | bash
```

It asks four questions (AI attribution in commits, branch-and-PR workflow, default branch, languages), then writes:

| File        | Read by                                                        | Content                                 |
|-------------|----------------------------------------------------------------|-----------------------------------------|
| `AGENTS.md` | Codex, Antigravity, Grok Build, Cursor, Copilot, Jules, Claude Code (via import) | **Single source of truth**              |
| `CLAUDE.md` | Claude Code                                                    | `@AGENTS.md` import, one sentence       |
| `GEMINI.md` | Gemini CLI, Antigravity                                        | One-sentence pointer to `AGENTS.md`     |

`AGENTS.md` is the source of truth because it is the cross-tool standard. Grok Build and Antigravity read it natively, so there is no separate `GROK.md` or lowercase `agents.md` (the latter would collide with `AGENTS.md` on macOS and Windows).

## What goes in AGENTS.md

- **Project**: a stub for you to fill in (purpose, build, test, run). Agents read this first.
- **Workflow**: verify before claiming done, small commits, no destructive git; plus your branch and attribution choices.
- **Code**: idiomatic style, YAGNI, DRY without premature abstraction, self-documenting code, comments for *why*, testing, dependencies, security, scope.
- **Languages**: four to six bullets per detected language. Supported: `install.sh --list-langs` (C, C++, Rust, Go, Ruby, Python, JavaScript, TypeScript, Swift, Objective-C, Java, Kotlin, C#, PHP, Shell, SQL, Dart, Elixir).

The generated part sits between `<!-- aipair:begin -->` and `<!-- aipair:end -->`. Re-running replaces only that block, so everything you write outside it survives. An existing `AGENTS.md` without markers gets the block appended; existing `CLAUDE.md`/`GEMINI.md` files are left alone unless you pass `--force`.

## Non-interactive use

```sh
curl -fsSL https://raw.githubusercontent.com/xuancongwen/aipair/main/install.sh \
  | bash -s -- -y --attribution no --branches yes --langs go,typescript
```

```
-C, --dir DIR             project directory (default: .)
-y, --yes                 skip prompts, use flags and defaults
    --attribution yes|no  keep AI attribution in commits (default: no)
    --branches yes|no     branch per task, PR before every merge (default: yes)
    --default-branch NAME protected branch (default: detected, else main)
    --langs LIST          comma-separated ids, auto (default), or none
    --stdout              print AGENTS.md instead of writing files
    --force               overwrite foreign CLAUDE.md/GEMINI.md (keeps *.bak)
```

## Developing

```
src/aipair.sh      the script; reads templates/ directly
templates/         one file per section and per language
install.sh         generated: src + embedded templates. Do not edit by hand.
test/run.sh        end-to-end tests
```

`make test` rebuilds `install.sh` and runs the suite against both the source and the built script. `make check` fails if `install.sh` is stale. Templates aim for the minimum context that still changes agent behavior: prefer deleting a bullet to adding one.

## License

MIT

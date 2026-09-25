# aipair

One instruction file for every AI coding agent in your project. Run this in your project directory:

```sh
curl -fsSL https://raw.githubusercontent.com/xuancongwen/aipair/main/install.sh | bash
```

You get four prompts. Press Enter to accept each default, or skip them all with `-y`:

```sh
curl -fsSL https://raw.githubusercontent.com/xuancongwen/aipair/main/install.sh | bash -s -- -y
```

| Prompt | Default | Flag |
|---|---|---|
| Keep AI attribution (Co-Authored-By) in commits? | no | `--attribution yes\|no` |
| Work on branches and open a PR before every merge? | yes | `--branches yes\|no` |
| Protected default branch | detected from git, else `master` | `--default-branch NAME` |
| Languages to include | auto-detected from your files | `--langs go,rust` or `none` |

Flags combine with `-y`, so `-y --attribution yes` answers one question and defaults the rest. Then fill in the **Project** section at the top of `AGENTS.md` (purpose, build, test, run); it is the first thing agents read.

## What gets written

| File | Read by | Content |
|---|---|---|
| `AGENTS.md` | Codex, Antigravity, Grok Build, Cursor, Copilot, Jules, Claude Code (via import) | **Single source of truth** |
| `CLAUDE.md` | Claude Code | `@AGENTS.md` import plus one sentence |
| `GEMINI.md` | Gemini CLI, Antigravity | One-sentence pointer to `AGENTS.md` |

`AGENTS.md` is the source of truth because it is the cross-tool standard. Grok Build and Antigravity read it natively, so there is no separate `GROK.md` or lowercase `agents.md` (the latter would collide with `AGENTS.md` on macOS and Windows).

`AGENTS.md` contains:

- **Project**: a stub for you to fill in.
- **Workflow**: verify before claiming done, small commits, no destructive git, plus your branch and attribution choices.
- **Code**: idiomatic style, YAGNI, DRY without premature abstraction, self-documenting code, comments for *why*, testing, dependencies, security, scope.
- **Languages**: four to six bullets per detected language. Supported: C, C++, Rust, Go, Ruby, Python, JavaScript, TypeScript, Swift, Objective-C, Java, Kotlin, C#, PHP, Shell, SQL, Dart, Elixir (`--list-langs` prints the ids).

A Rust plus TypeScript project comes out at about 45 lines. The goal is the minimum context that still changes agent behavior.

## Re-running and existing files

The generated part sits between `<!-- aipair:begin -->` and `<!-- aipair:end -->`. Re-running replaces only that block, so the Project section and anything else you write survives. Re-run to change an answer, add a language, or pick up template updates.

- An existing `AGENTS.md` without markers gets the block appended.
- Existing `CLAUDE.md` or `GEMINI.md` files that do not reference `AGENTS.md` are left alone. Pass `--force` to overwrite them; the original is kept as `*.bak`.

## All options

```
-C, --dir DIR             project directory (default: .)
-y, --yes                 skip prompts, use flags and defaults
    --attribution yes|no  keep AI attribution in commits (default: no)
    --branches yes|no     branch per task, PR before every merge (default: yes)
    --default-branch NAME protected branch (default: detected, else master)
    --langs LIST          comma-separated ids, auto (default), or none
    --list-langs          print supported language ids
    --stdout              print AGENTS.md instead of writing files
    --force               overwrite foreign CLAUDE.md/GEMINI.md (keeps *.bak)
```

Prompts read from the terminal even when the script is piped through curl.

## Developing

```
src/aipair.sh      the script; reads templates/ directly
templates/         one Markdown file per section and per language
build.sh           pastes templates/ into src/aipair.sh to produce install.sh
install.sh         generated, self-contained. Do not edit by hand.
test/run.sh        end-to-end tests
```

The curl one-liner needs a single file, but instructions are easier to edit as small Markdown files, so `build.sh` bridges the two. `make test` rebuilds `install.sh` and runs the suite against both the source and the built script. `make check` fails if `install.sh` is stale. When editing templates, prefer deleting a bullet to adding one.

## License

MIT

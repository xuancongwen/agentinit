# aipair

One instruction file for every AI coding agent in your project. Run this in the project directory:

```sh
curl -fsSL https://raw.githubusercontent.com/xuancongwen/aipair/main/install.sh | bash
```

Four prompts follow. Enter accepts each default; `-y` skips them all:

```sh
curl -fsSL https://raw.githubusercontent.com/xuancongwen/aipair/main/install.sh | bash -s -- -y
```

| Prompt | Default | Flag |
|---|---|---|
| Keep AI attribution (Co-Authored-By) in commits? | no | `--attribution yes\|no` |
| Work on branches and open a PR before every merge? | yes | `--branches yes\|no` |
| Protected default branch | detected, else `master` | `--default-branch NAME` |
| Languages to include | detected from your files | `--langs go,rust` or `none` |

Flags combine with `-y`. Afterwards, fill in the **Project** section at the top of `AGENTS.md`; agents read it first.

## What gets written

| File | Read by | Content |
|---|---|---|
| `AGENTS.md` | Codex, Antigravity, Grok Build, Cursor, Copilot, Jules, Claude Code (via import) | **Single source of truth** |
| `CLAUDE.md` | Claude Code | `@AGENTS.md` import |
| `GEMINI.md` | Gemini CLI, Antigravity | Pointer to `AGENTS.md` |

`AGENTS.md` is the cross-tool standard, and Grok Build and Antigravity read it natively, so there is no `GROK.md` or lowercase `agents.md` (which would collide with `AGENTS.md` on macOS and Windows).

`AGENTS.md` holds a **Project** stub, a **Workflow** section (verify before claiming done, small commits, no destructive git, your branch and attribution choices), a **Code** section (idioms, YAGNI, DRY without premature abstraction, self-documenting code, comments for *why*, testing, dependencies, security, scope), and four to five bullets per language. Supported: C, C++, Rust, Go, Ruby, Python, JavaScript, TypeScript, Swift, Objective-C, Java, Kotlin, C#, PHP, Shell, SQL, Dart, Elixir. A Rust plus TypeScript project comes to about 45 lines.

## Re-running

The generated part sits between `<!-- aipair:begin -->` and `<!-- aipair:end -->`. Re-running replaces only that block; everything you write outside it survives. An existing `AGENTS.md` without markers gets the block appended. Existing `CLAUDE.md` or `GEMINI.md` files that do not reference `AGENTS.md` are left alone unless you pass `--force`, which keeps a `*.bak`.

## Options

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

Prompts read from the terminal even when piped through curl.

## Developing

```
src/aipair.sh   the script; reads templates/ directly
templates/      one Markdown file per section and per language
build.sh        embeds templates/ into src/aipair.sh to produce install.sh
install.sh      generated, self-contained; do not edit by hand
test/run.sh     end-to-end tests
```

`make test` rebuilds `install.sh` and tests both scripts. `make check` fails if `install.sh` is stale. When editing templates, prefer deleting a bullet to adding one.

## License

MIT

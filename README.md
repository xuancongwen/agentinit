# agentinit

One instruction file for every AI coding agent in your project. Run this in the project directory:

```sh
curl -fsSL https://raw.githubusercontent.com/xuancongwen/agentinit/master/install.sh | bash
```

Four prompts follow. Enter accepts each default; `-y` skips them all:

```sh
curl -fsSL https://raw.githubusercontent.com/xuancongwen/agentinit/master/install.sh | bash -s -- -y
```

| Prompt | Default | Flag |
|---|---|---|
| Keep AI attribution (Co-Authored-By) in commits? | no | `--attribution yes\|no` |
| Branch workflow: `yes`, `early`, or `no` | yes | `--branches yes\|early\|no` |
| Default branch | detected, else `master` | `--default-branch NAME` |
| Languages to include | detected from your files | `--langs go,rust` or `none` |

Flags combine with `-y`. Afterwards, fill in the **Project** section at the top of `AGENTS.md`; agents read it first.

## Branch workflow

| `--branches` | Agents work in | Changes reach the default branch by |
|---|---|---|
| `yes` | their own `git worktree` and branch, one per task | a PR |
| `early` | their own `git worktree` and branch, one per task | rebasing and pushing directly |
| `no` | the current checkout and branch | committing in place |

`early` drops PR overhead during initial development. When the project needs review gates, re-run with `--branches yes`; only the managed block changes.

With `yes` and `early`, agents never work in your main checkout, even when only one agent is running: every task starts with `git worktree add ../<repo>-<task> -b <task>` and all edits and commits happen in that sibling directory, which shares the same `.git`. Your checkout stays on the default branch and untouched, and agents never switch branches or overwrite files under one another. `AGENTS.md` also gives agents a check for whether they are in the main checkout, so one that starts there moves out before changing anything.

## What gets written

| File | Read by | Content |
|---|---|---|
| `AGENTS.md` | Codex, Antigravity, Grok Build, Cursor, Windsurf, Copilot, Jules, Claude Code (via import) | **Single source of truth** |
| `CLAUDE.md` | Claude Code | `@AGENTS.md` import |
| `GEMINI.md` | Gemini CLI, Antigravity | Pointer to `AGENTS.md` |

`AGENTS.md` is the cross-tool standard, and Grok Build and Antigravity read it natively, so there is no `GROK.md` or lowercase `agents.md` (which would collide with `AGENTS.md` on macOS and Windows).

Cursor and Windsurf apply a root `AGENTS.md` to every session, so agentinit writes none of their own rule files. Those files load alongside `AGENTS.md`, so agentinit flags any it finds, to fold into `AGENTS.md` or delete:

| Tool | Rule files | Notes |
|---|---|---|
| Cursor | `.cursor/rules/*.mdc`, legacy `.cursorrules` | `.mdc` frontmatter: `description`, `globs`, `alwaysApply`; plain `.md` in `.cursor/rules` is ignored |
| Windsurf | `.devin/rules/*.md`, `.windsurf/rules/*.md`, legacy `.windsurfrules`; global `~/.codeium/windsurf/memories/global_rules.md` | frontmatter `trigger: always_on\|manual\|model_decision\|glob`; 12,000 characters per file, so agentinit warns when `AGENTS.md` exceeds that |

Both also read nested `AGENTS.md` files, scoped to their directory.

`AGENTS.md` holds a **Project** stub, a **Workflow** section (verify before claiming done, small commits, no destructive git, your branch, worktree, and attribution choices), a **Code** section (idioms, YAGNI, DRY without premature abstraction, self-documenting code, comments for *why*, testing, dependencies, security, scope), and four to five bullets per language. Supported: C, C++, Rust, Go, Ruby, Python, JavaScript, TypeScript, Swift, Objective-C, Java, Kotlin, C#, PHP, Shell, SQL, Dart, Elixir. A Rust plus TypeScript project comes to about 50 lines.

## Re-running

The generated part sits between `<!-- agentinit:begin -->` and `<!-- agentinit:end -->`. Re-running replaces only that block; everything you write outside it survives. An existing `AGENTS.md` without markers gets the block appended. Existing `CLAUDE.md` or `GEMINI.md` files that do not reference `AGENTS.md` are left alone unless you pass `--force`, which keeps a `*.bak`.

## Options

```
-C, --dir DIR             project directory (default: .)
-y, --yes                 skip prompts, use flags and defaults
    --attribution yes|no  keep AI attribution in commits (default: no)
    --branches MODE       yes: branch + PR per task (default); early: push straight
                          to the default branch; no: current branch, no PRs
    --default-branch NAME default branch (default: detected, else master)
    --langs LIST          comma-separated ids, auto (default), or none
    --list-langs          print supported language ids
    --stdout              print AGENTS.md instead of writing files
    --force               overwrite foreign CLAUDE.md/GEMINI.md (keeps *.bak)
```

Prompts read from the terminal even when piped through curl.

## Developing

```
src/agentinit.sh   the script; reads templates/ directly
templates/      one Markdown file per section and per language
build.sh        embeds templates/ into src/agentinit.sh to produce install.sh
install.sh      generated, self-contained; do not edit by hand
test/run.sh     end-to-end tests
```

`make test` rebuilds `install.sh` and tests both scripts. `make check` fails if `install.sh` is stale. When editing templates, prefer deleting a bullet to adding one.

## License

MIT

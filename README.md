# agentinit

One instruction file for every AI coding agent in your project. Run this in the project directory:

```sh
curl -fsSL https://raw.githubusercontent.com/xuancongwen/agentinit/master/install.sh | bash
```

Five prompts follow. Enter accepts each default; `-y` skips them all:

```sh
curl -fsSL https://raw.githubusercontent.com/xuancongwen/agentinit/master/install.sh | bash -s -- -y
```

| Prompt | Default | Flag |
|---|---|---|
| Keep AI attribution (Co-Authored-By) in commits? | no | `--attribution yes\|no` |
| Mode: `build` or `iterate` | iterate | `--mode build\|iterate` |
| Default branch | detected, else `master` | `--default-branch NAME` |
| Task tracker agents keep updated | `github` | `--tracker github\|none\|NAME` |
| Languages to include | detected from your files | `--langs go,rust` or `none` |

Flags combine with `-y`. Afterwards, fill in the **Project** section at the top of `AGENTS.md`; agents read it first.

## Modes

| `--mode` | Agents work in | Changes reach the default branch by |
|---|---|---|
| `build` | the main checkout, on the default branch | committing straight to it |
| `iterate` | their own `git worktree` and branch, one per task | a PR |

Use `build` while you are building the project out with one agent at a time, and `iterate` once it needs review gates or parallel agents. Your settings are saved in `AGENTS.md`, so switching touches nothing else:

```sh
curl -fsSL https://raw.githubusercontent.com/xuancongwen/agentinit/master/install.sh | bash -s -- --mode iterate
```

With an alias such as `alias agentinit='curl -fsSL https://raw.githubusercontent.com/xuancongwen/agentinit/master/install.sh | bash -s --'`, this becomes `agentinit --mode build` or `agentinit --mode iterate`.

In `iterate`, agents never work in your main checkout, even when only one agent is running. Before its first edit, each task gets a worktree inside the project: `.worktrees/<task>`, or `.claude/worktrees/<task>` when Claude Code uses its own `EnterWorktree` tool. Both directories are added to `.gitignore`. Worktrees live inside the project because agent sandboxes (Claude Code, Codex) only allow writes there, and an agent blocked from a sibling directory falls back to the main checkout. `AGENTS.md` also covers the two other ways agents slip: harnesses that "branch first" with `git checkout -b` in the main checkout, and agents that create a worktree but keep editing files by their main-checkout paths.

## Task tracking

| `--tracker` | Agents track each task in |
|---|---|
| `github` | a GitHub issue, via `gh` or the GitHub MCP |
| any other name, e.g. `Trackstar` | a story or ticket in that tracker, via its MCP server |
| `none` | nothing; the section is omitted |

Agents find or open the task's issue before starting and update it while they work: when they start, when the plan changes, when they are blocked, and when the work lands. The issue always shows where the work stands, and closes only when the change lands. If the tracker is unreachable, agents say so instead of skipping it.

## Attribution

`--attribution no` (the default) tells agents in `AGENTS.md` to leave out `Co-Authored-By` trailers and "Generated with" footers. Claude Code adds both by default, and that default tends to win over an instruction, so agentinit also sets `"attribution": {"commit": "", "pr": ""}` in `.claude/settings.json`. It creates the file if it is missing and merges into an existing one with `jq` (without `jq`, it prints the line to add). `--attribution yes` removes the override again.

## What gets written

| File | Read by | Content |
|---|---|---|
| `AGENTS.md` | Codex, Antigravity, Grok Build, Cursor, Windsurf, Copilot, Jules, Claude Code (via import) | **Single source of truth** |
| `CLAUDE.md` | Claude Code | `@AGENTS.md` import |
| `GEMINI.md` | Gemini CLI, Antigravity | Pointer to `AGENTS.md` |
| `.claude/settings.json` | Claude Code | Attribution off, with `--attribution no` |
| `.gitignore` | git | `.worktrees/` and `.claude/worktrees/`, with `--mode iterate` |

`AGENTS.md` is the cross-tool standard, and Grok Build and Antigravity read it natively, so there is no `GROK.md` or lowercase `agents.md` (which would collide with `AGENTS.md` on macOS and Windows).

Cursor and Windsurf apply a root `AGENTS.md` to every session, so agentinit writes none of their own rule files. Those files load alongside `AGENTS.md`, so agentinit flags any it finds, to fold into `AGENTS.md` or delete:

| Tool | Rule files | Notes |
|---|---|---|
| Cursor | `.cursor/rules/*.mdc`, legacy `.cursorrules` | `.mdc` frontmatter: `description`, `globs`, `alwaysApply`; plain `.md` in `.cursor/rules` is ignored |
| Windsurf | `.devin/rules/*.md`, `.windsurf/rules/*.md`, legacy `.windsurfrules`; global `~/.codeium/windsurf/memories/global_rules.md` | frontmatter `trigger: always_on\|manual\|model_decision\|glob`; 12,000 characters per file, so agentinit warns when `AGENTS.md` exceeds that |

Both also read nested `AGENTS.md` files, scoped to their directory.

`AGENTS.md` holds a **Project** stub, a **Workflow** section (verify before claiming done, small commits, no destructive git, your mode and attribution choices), a **Task tracking** section for your tracker, a **Code** section (idioms, YAGNI, DRY without premature abstraction, self-documenting code, comments for *why*, testing, dependencies, security, scope), and four to five bullets per language. Supported: C, C++, Rust, Go, Ruby, Python, JavaScript, TypeScript, Swift, Objective-C, Java, Kotlin, C#, PHP, Shell, SQL, Dart, Elixir. A Rust plus TypeScript project comes to about 50 lines.

## Re-running

The generated part sits between `<!-- agentinit:begin -->` and `<!-- agentinit:end -->`, and its first line records your settings. Re-running reuses them, so it asks only about settings that are not saved, and flags change only what they name. Re-running replaces only that block; everything you write outside it survives. An existing `AGENTS.md` without markers gets the block appended. Existing `CLAUDE.md` or `GEMINI.md` files that do not reference `AGENTS.md` are left alone unless you pass `--force`, which keeps a `*.bak`.

## Options

```
-C, --dir DIR             project directory (default: .)
-y, --yes                 skip prompts, use flags, saved settings, and defaults
    --attribution yes|no  keep AI attribution in commits (default: no)
    --mode build|iterate  build: commit straight to the default branch;
                          iterate: worktree, branch, and PR per task (default)
    --default-branch NAME default branch (default: detected, else master)
    --tracker NAME        github (default), none, or another tracker's MCP name
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

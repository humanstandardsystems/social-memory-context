# social-memory-context

Shared, project-scoped memory for Claude Code. A skill-driven plugin that lets two or more humans (and their Claude sessions) share decisions, todos, glossary terms, and context through a git-backed markdown folder.

Designed to plug into [Human Standard (hs)](https://github.com/humanstandardsystems/hs) — uses hs's existing `/done` plugin hook to auto-commit and push the brain at end of session.

## What it does

- `/brain init` — scaffolds a "brain" folder for the current project and wires it into hs.
- `/brain decide "<gist>"` — records a decision with reasoning.
- `/brain todo "<text>"` — adds a todo.
- `/brain done-todo "<query>"` — closes a matching todo.
- `/brain glossary "<term>"` — adds or updates a glossary entry.
- `/brain context "<gist>"` — records current state of something.
- `/brain sync` — manually pull the latest brain state.

Auto-syncs on session start (silent `git pull`). Auto-pushes on `/done` (via hs hook).

## Install

```bash
# 1. Clone to the canonical sources location
git clone https://github.com/humanstandardsystems/social-memory-context.git ~/.claude/sources/social-memory-context

# 2. Install the brain skill globally
bash ~/.claude/sources/social-memory-context/install.sh
```

That copies the brain skill into `~/.claude/skills/brain/`. No deps, no scripts.

## Updating

```bash
bash ~/.claude/sources/social-memory-context/update.sh
```

## Uninstalling

See [UNINSTALL.md](UNINSTALL.md) — `bash ~/.claude/sources/social-memory-context/uninstall.sh` removes the skill while preserving your brain repos.

## First use

Open a Claude Code session in a project that has hs installed and run:

```
/brain init
```

Claude will ask for:
- A name for the brain (defaults to `<project-name>-brain`)
- A GitHub repo URL (existing or to-create — leave blank to skip remote)
- Where the brain folder lives locally (defaults to a sibling of your project)
- Your author slug (used to attribute writes)

After init, the brain is live. Anything written via `/brain <subcommand>` gets staged. Run `/done` to commit + push (handled by hs).

## How the wiring works

`/brain init` does three things to the project:
1. Adds a `brain: <relative-path>` line to the project's `CLAUDE.md`
2. Drops `plugins/Brain/plugin.json` and `plugins/Brain/done.md` into the project root (so hs's `/done` picks up the brain push)
3. Adds a `SessionStart` hook to your `~/.claude/settings.json` that quietly pulls the brain on each new session

If you don't have hs installed, you'll need to push manually with `cd <brain-path> && git push` after writes.

## Scale

Designed for **2–5 humans sharing one brain**. Beyond that, use real collaboration tools — git merge conflicts on the same brain file get tedious past a small group.

## License

MIT

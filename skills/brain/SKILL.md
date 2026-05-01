---
name: brain
description: Project-scoped shared memory backed by a git repo. Use to record decisions, todos, glossary terms, and context that persist across sessions and sync between collaborators. Plugs into Human Standard (hs) — auto-pulls on SessionStart, auto-pushes on /done.
when_to_use: When the user runs /brain or any /brain <subcommand> (init, decide, todo, done-todo, glossary, context, sync). Also when the user explicitly says "save this to brain" or "this should go in the brain."
---

# /brain — shared memory plugin

You are operating the brain plugin. The user has installed this skill to manage a project-scoped, git-backed knowledge base shared with collaborators (typically a small team or family).

## Mental model

A "brain" is a folder of markdown files committed to a git repo. The folder lives next to (not inside) the project it serves. The project's `CLAUDE.md` has a `brain:` line pointing at the brain folder. The brain folder has a `brain.json` marking it.

Storage = one record per file. Folders by topic:

- `decisions/` — choices made, with reasoning
- `todos/open/` and `todos/done/` — actionable items
- `glossary/` — defined terms
- `context/` — current state of things

Each file: YAML frontmatter + markdown body. Filenames are deterministic and dedup-safe.

## Routing

The user types `/brain <subcommand> [args]`. Route based on the subcommand:

| Subcommand | Section to follow |
|---|---|
| `init` | [/brain init](#brain-init) |
| `decide` | [/brain decide](#brain-decide) |
| `todo` | [/brain todo](#brain-todo) |
| `done-todo` | [/brain done-todo](#brain-done-todo) |
| `glossary` | [/brain glossary](#brain-glossary) |
| `context` | [/brain context](#brain-context) |
| `sync` | [/brain sync](#brain-sync) |
| (none / unknown) | Print available subcommands |

If the user just types `/brain` with no subcommand, print the list and stop.

---

## /brain init

Scaffolds a brain for the current project. Idempotent — running twice is safe.

### Steps

1. **Find the project root.** Walk up from cwd until you find a `CLAUDE.md` or hit a git repo root (`.git/`). Use the highest ancestor with a `CLAUDE.md`; if none, use cwd.

2. **Ask the user (one prompt batched, all four):**
   - Brain name (default: `<project-folder-name>-brain`)
   - GitHub repo URL (existing or to-be-created — leave blank to skip remote entirely)
   - Local path for the brain folder (default: sibling of the project, e.g. `../<brain-name>`)
   - Author slug (used to attribute writes; default: slugified `git config user.name`)

3. **Resolve local brain path** to absolute. Note its location relative to the project root for the `brain:` line later.

4. **Set up the brain folder:**
   - **If the local path doesn't exist:**
     - If a GitHub repo URL was given AND that repo has commits: `git clone <url> <local-path>`
     - Otherwise: create the directory, run `git init`, scaffold from templates below.
   - **If the local path exists:**
     - Verify it's a git repo (`<path>/.git/` exists). If not, error and stop.
     - Verify it has a `brain.json` OR scaffold one if missing (use templates below).

5. **Scaffold these files inside the brain folder if missing** (do not overwrite existing):

   `brain.json`:
   ```json
   {
     "name": "<brain-name>",
     "version": 1,
     "topics": ["decisions", "glossary", "context", "todos"],
     "created": "<ISO-8601-UTC-now>"
   }
   ```

   `CLAUDE.md`:
   ```markdown
   # <brain-name>

   This is a brain — a shared, git-backed memory store for the <project-name> project.

   me: <author-slug>

   When opened directly (not as a referenced brain), behave like Cloudy in any other session — but treat this folder's markdown files as the source of truth for project context.
   ```

   `README.md`:
   ```markdown
   # <brain-name>

   Shared memory for <project-name>. Managed by the [brain](https://github.com/humanstandardsystems/social-memory-context) skill.

   ## Layout

   - `decisions/` — choices made, with reasoning
   - `todos/open/`, `todos/done/` — actionable items
   - `glossary/` — defined terms
   - `context/` — current state of things

   Read any `.md` file directly to inspect. Edits are committed via `/done` from a Claude Code session that has this brain wired up.
   ```

   Empty folders to create:
   - `decisions/`
   - `glossary/`
   - `todos/open/`
   - `todos/done/`
   - `context/`

   (Drop a `.gitkeep` in each empty folder so git tracks them.)

6. **If a GitHub URL was given and the repo is empty / new:** add the remote (`git remote add origin <url>`), commit the scaffold (`git add -A && git commit -m "brain: initial scaffold"`), and push (`git push -u origin main`).

7. **Wire the project to the brain.** Project root = cwd's nearest CLAUDE.md ancestor (from step 1).

   - **Add `brain:` line to project's CLAUDE.md.** If CLAUDE.md doesn't exist, create it. If it exists, check whether a `brain:` line is already present:
     - If present and matches the resolved relative path: do nothing.
     - If present but different: ask the user before overwriting.
     - If absent: append a new line `brain: <relative-path-from-project-root-to-brain>`.

   - **Create `<project-root>/plugins/Brain/plugin.json`** (if missing):
     ```json
     {
       "name": "Brain",
       "version": "1.0.0",
       "description": "Shared git-backed memory. Pushes brain on /done.",
       "done_hook": "plugins/Brain/done.md"
     }
     ```

   - **Create `<project-root>/plugins/Brain/done.md`** (if missing):
     ```markdown
     # Brain plugin — /done hook

     When /done runs, this hook fires.

     1. Read the project's CLAUDE.md. Find the line matching `^\s*brain:\s*(\S+)\s*$`. If no `brain:` line, skip silently.
     2. Resolve the brain path relative to the CLAUDE.md's directory.
     3. Run `git -C <brain-path> status --porcelain`. If empty, skip — nothing to commit.
     4. Otherwise:
        - `git -C <brain-path> add -A`
        - `git -C <brain-path> commit -m "brain: session update <YYYY-MM-DD>"`
        - `git -C <brain-path> push`
     5. If the push fails because the remote has new commits: `git -C <brain-path> pull --rebase --autostash` and retry the push once. If it still fails, surface the error verbatim and stop.
     ```

8. **Add the SessionStart auto-pull hook** to `~/.claude/settings.json`. The hook command is:
   ```
   bash ~/.claude/skills/brain/sync.sh
   ```

   Idempotency check: scan existing `hooks.SessionStart[*].hooks[*].command` strings. If any contains the substring `skills/brain/sync.sh`, skip — already wired.

   Otherwise, append a new entry. If `hooks.SessionStart` doesn't exist, create it. Use Python or `jq` for safe JSON edits — never hand-format JSON.

9. **Confirm** with a short summary:
   ```
   Brain initialized.
     local:   <absolute-path>
     remote:  <url-or-none>
     project: <project-root>

   Try: /brain decide "your first decision"
   ```

---

## /brain decide

Records a decision. The user invokes as `/brain decide "<gist>"`, where `<gist>` is one short line (the punchline).

### Steps

1. **Resolve the brain.** See [Resolving the brain](#resolving-the-brain). If not configured, error: `no brain configured for this project. Run /brain init.`

2. **Determine author.** Read the brain's `CLAUDE.md` for a line matching `^\s*me:\s*(\S+)\s*$`. If found, use that. Otherwise, slugify `git config user.name`. Fallback: `unknown`.

3. **Extract from conversation context:**
   - **gist** — the line the user gave you (max 70 chars; truncate with ellipsis if longer)
   - **body** — the reasoning. Pull from the recent conversation. If the user gave a one-liner with no context, ask them for the "why" before writing.
   - **importance** — `critical` | `high` | `medium` | `low` (decisions default to `high`)
   - **keywords** — 2–5 short lowercase tags relevant to the decision

4. **Compute the dedup hash.**
   ```bash
   FULL_HASH=$(printf '%s' "decision|<author>|<gist>|<body>" | shasum -a 256 | awk '{print $1}')
   SHORT=${FULL_HASH:0:8}
   ```

5. **Check for duplicates.** Look for any existing file in `<brain>/decisions/` matching the pattern `*-<author>-<SHORT>.md`. If found: print `already recorded: <existing-filename> — skipping` and stop.

6. **Build filename:**
   ```
   <YYYY-MM-DDTHHMMSS-UTC>-<author>-<SHORT>.md
   ```
   Example: `2026-04-21T143022-source-a3f9c1d2.md`

7. **Write the file** at `<brain>/decisions/<filename>` with this exact frontmatter:
   ```markdown
   ---
   id: <FULL_HASH>
   type: decision
   author: <author>
   created: <ISO-8601-UTC>
   importance: <importance>
   keywords: [<tag1>, <tag2>, <tag3>]
   ---

   # <gist>

   <body>
   ```

8. **Stage it:** `git -C <brain> add <relative-path-to-file>`. **Do not commit.** Commits happen on `/done` via the hs hook.

9. **Confirm in one line:** `Decided: <gist>`

---

## /brain todo

Same shape as `/brain decide` with these differences:

- **type:** `todo`
- **folder:** `<brain>/todos/open/`
- **default importance:** `medium`
- **gist:** the todo text itself (e.g. "Email landlord about HVAC")
- **body:** any additional context; if user gave none, body can just restate the gist

Confirm: `Todo added: <gist>`

---

## /brain done-todo

Closes a todo. User invokes as `/brain done-todo "<query>"`.

### Steps

1. Resolve the brain.
2. Search `<brain>/todos/open/` for files where `<query>` (lowercased) appears in either the filename or the body. Collect all matches.
3. **If 0 matches:** error `no open todo matches: "<query>"`. Stop.
4. **If >1 matches:** print the list (filenames) and ask the user to be more specific. Stop.
5. **If exactly 1 match:**
   - Read the file.
   - Insert these two lines into the frontmatter, immediately after the `created:` line:
     ```
     closed: <ISO-8601-UTC-now>
     closed_by: <author>
     ```
   - Write the modified content to `<brain>/todos/done/<original-filename>`.
   - Delete the original from `<brain>/todos/open/`.
   - Stage both: `git -C <brain> add todos/open/<file> todos/done/<file>` (`add -A` is fine here too, scoped to those two paths).
6. Confirm: `Closed: <gist-from-frontmatter-h1>`

---

## /brain glossary

Adds or updates a glossary term. User invokes as `/brain glossary "<term>"` with the definition body coming from conversation context.

### Steps

1. Resolve the brain.
2. Determine author.
3. **Extract definition body** from conversation context. If unclear, ask the user.
4. **Slugify the term:** lowercase, replace non-alphanumeric runs with single hyphens, trim leading/trailing hyphens. (e.g. "Token Ledger" → `token-ledger`)
5. **Path:** `<brain>/glossary/<slug>.md`
6. **If file exists:**
   - Read it. Extract the existing `created:` value to preserve.
   - Use that as `created:` in the new frontmatter; set `updated:` to now.
7. **If file is new:**
   - Set both `created:` and `updated:` to now.
8. **Compute the hash:**
   ```bash
   FULL_HASH=$(printf '%s' "glossary|<slug>|<body>" | shasum -a 256 | awk '{print $1}')
   ```
9. **Write the file:**
   ```markdown
   ---
   id: <FULL_HASH>
   type: glossary
   author: <author>
   created: <preserved-or-now>
   updated: <now>
   importance: high
   keywords: [<slug>]
   ---

   # <term>

   <body>
   ```
10. Stage: `git -C <brain> add glossary/<slug>.md`
11. Confirm: `Glossary updated: <term>` (or `Glossary added: <term>` if new)

---

## /brain context

Same shape as `/brain decide` with these differences:

- **type:** `context`
- **folder:** `<brain>/context/`
- **default importance:** `medium`

Use this for "current state" notes — bookings, listings, ongoing situations. Decisions are *choices made*; context is *how things are right now*.

Confirm: `Context recorded: <gist>`

---

## /brain sync

Manual pull from the remote. Use mid-session when a collaborator says "I just pushed something."

### Steps

1. Resolve the brain.
2. Run `git -C <brain> pull --rebase --autostash`. If it fails, surface the error and stop.
3. Run `git -C <brain> log --oneline -10` and summarize the recent commits in 1–3 sentences. Skip any that look like your own previous commits (same author).
4. If nothing new since last sync: say `Brain's already current.`
5. Otherwise: say `Pulled <N> new commits. Recent: <one-line summary>.`

---

## Resolving the brain

This logic is used by every subcommand except `/brain init`.

1. Start from cwd.
2. Walk up the parent chain.
3. At each level, check for `CLAUDE.md`. If present, scan it for a line matching the regex `^\s*brain:\s*(\S+)\s*$`.
4. If matched: resolve the captured path relative to the directory containing that CLAUDE.md → that's `<brain>`.
5. Verify `<brain>/brain.json` exists. If not, error: `<path> has no brain.json — not a valid brain folder`.
6. Verify `<brain>/.git/` exists. If not, error: `<path> is not a git repo`.
7. If no `brain:` line is found in any ancestor's CLAUDE.md before hitting `/`: error `no brain configured for this project. Run /brain init.`

---

## File format reference (verbatim)

### Standard record (decision / todo / context)

```markdown
---
id: <FULL_SHA256>
type: decision|todo|context
author: <author-slug>
created: <ISO-8601-UTC>
importance: critical|high|medium|low
keywords: [tag1, tag2]
---

# <gist>

<body markdown>
```

### Closed todo (additional fields)

After `created:`, before `importance:`:

```
closed: <ISO-8601-UTC>
closed_by: <author-slug>
```

### Glossary record

```markdown
---
id: <FULL_SHA256>
type: glossary
author: <author-slug>
created: <ISO-8601-UTC>
updated: <ISO-8601-UTC>
importance: high
keywords: [<slug>]
---

# <term>

<definition body>
```

### Filename patterns

| Folder | Pattern |
|---|---|
| `decisions/`, `todos/open/`, `todos/done/`, `context/` | `<YYYY-MM-DDTHHMMSS>-<author-slug>-<hash8>.md` (timestamp in UTC, no colons) |
| `glossary/` | `<term-slug>.md` |

### Slug rules

- Lowercase only.
- `[a-z0-9-]` only.
- Replace any run of disallowed chars with a single hyphen.
- Trim leading/trailing hyphens.
- Empty result → `untitled`.

### Hash recipe (Bash)

```bash
# For decision/todo/context:
HASH=$(printf '%s' "<type>|<author>|<gist>|<body>" | shasum -a 256 | awk '{print $1}')

# For glossary:
HASH=$(printf '%s' "glossary|<slug>|<body>" | shasum -a 256 | awk '{print $1}')

# Use full hash in `id:` field, first 8 chars in filename.
```

### Timestamps

- Always UTC, ISO-8601 with `Z` suffix in frontmatter (`2026-04-21T14:30:22Z`).
- In filenames, use `YYYY-MM-DDTHHMMSS` (no colons, no `Z`) for filesystem safety.

---

## Hard rules — do not violate

1. **Never commit on a write operation.** Only `git add`. Commits happen on `/done` via the hs plugin hook.
2. **Always use UTC for timestamps.** Use `date -u +%Y-%m-%dT%H:%M:%SZ` for frontmatter, `date -u +%Y-%m-%dT%H%M%S` for filenames.
3. **Never edit files in `<brain>/.git/`.**
4. **Never duplicate.** Always run the dedup hash check before writing decision/todo/context.
5. **Idempotency.** Re-running `/brain init` must not double-add the `brain:` line, duplicate the SessionStart hook, or overwrite an existing brain folder's content.
6. **Hs is required for auto-push.** If `~/.claude/commands/done.md` doesn't exist OR doesn't reference plugin hooks, warn the user that `/done` won't auto-push and they need to push manually.
7. **Surface errors verbatim.** Don't reword git or filesystem errors — pass them through so the user can debug.

# Uninstalling the brain skill

Removes the brain skill from `~/.claude/skills/brain/` and the SessionStart pull hook. Your **brain data** — the shared markdown repos like `americana-getaways-brain/` — is preserved.

## Quick uninstall

```bash
bash ~/.claude/sources/social-memory-context/uninstall.sh
```

The script asks for confirmation. After it finishes, the global `/brain` commands stop working but everything you wrote to your brain repos is intact.

## What the script removes

- `~/.claude/skills/brain/` — the skill itself (the `/brain init`, `/brain decide`, etc. commands)
- The SessionStart hook from `~/.claude/settings.json` that auto-pulls brain repos at session start

## What the script keeps

- Brain repos themselves (e.g. `~/humanstandard/businesses/americana-getaways-brain/`) — these are your shared memory data
- Per-project wiring (the `plugins/Brain/` folder and `brain:` line in each project's CLAUDE.md) — added by `/brain init`, needs manual cleanup
- The cloned source at `~/.claude/sources/social-memory-context/`

## Optional: clean per-project wiring

For each project where you ran `/brain init`:

```bash
cd <project>
rm -rf plugins/Brain
# Then edit CLAUDE.md to remove the line: brain: <relative-path>
```

## Optional: delete brain data and source

```bash
# Delete a brain repo (this removes shared memory — coordinate with collaborators first):
rm -rf ~/humanstandard/businesses/americana-getaways-brain

# Delete the cloned skill source:
rm -rf ~/.claude/sources/social-memory-context
```

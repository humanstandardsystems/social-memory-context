#!/usr/bin/env bash
# sync.sh — silent SessionStart auto-pull for the brain.
#
# Walks up from cwd looking for a CLAUDE.md with a `brain: <path>` line.
# Resolves that path relative to the CLAUDE.md's directory, then `git pull`.
# Fails silent so a network blip never blocks session startup.

P="$(pwd)"
while [ "$P" != "/" ] && [ "$P" != "." ]; do
    if [ -f "$P/CLAUDE.md" ]; then
        BRAIN=$(grep -E '^[[:space:]]*brain:[[:space:]]+' "$P/CLAUDE.md" 2>/dev/null \
                | head -1 \
                | sed -E 's/^[[:space:]]*brain:[[:space:]]+([^[:space:]]+).*/\1/')
        if [ -n "$BRAIN" ]; then
            BRAIN_ABS="$(cd "$P" 2>/dev/null && cd "$BRAIN" 2>/dev/null && pwd)"
            if [ -n "$BRAIN_ABS" ] && [ -d "$BRAIN_ABS/.git" ]; then
                git -C "$BRAIN_ABS" pull --rebase --autostash --quiet 2>/dev/null || true
            fi
            break
        fi
    fi
    P=$(dirname "$P")
done
exit 0

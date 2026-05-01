#!/usr/bin/env bash
# install.sh — install the brain skill into the user's Claude Code skills directory.
#
# Usage: bash install.sh
#
# Copies skills/brain/ to ~/.claude/skills/brain/. That's it.
# All brain operations are driven by SKILL.md at runtime.

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$HOME/.claude/skills/brain"

mkdir -p "$TARGET"
cp -R "$SOURCE_DIR/skills/brain/." "$TARGET/"

echo "Installed brain skill at $TARGET"
echo ""
echo "Next: open Claude Code in a project with hs installed and run:"
echo "  /brain init"

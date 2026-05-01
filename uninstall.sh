#!/usr/bin/env bash
# uninstall.sh — remove the brain skill and its SessionStart sync hook.
# Per-project wiring (plugins/Brain/, brain: line in CLAUDE.md) is NOT touched — clean those manually.

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_CLAUDE="$HOME/.claude"
SKILL_DIR="$USER_CLAUDE/skills/brain"

cat <<EOF
Uninstalling the brain skill.

Will REMOVE:
  - $SKILL_DIR (the brain skill — /brain init, /brain decide, etc.)
  - SessionStart hook from $USER_CLAUDE/settings.json (if present)

Will KEEP:
  - Per-project plugins/Brain/ folders (added by /brain init — clean manually)
  - The 'brain:' line in each project's CLAUDE.md (clean manually if desired)
  - Brain repos themselves (your shared memory data — e.g. americana-getaways-brain)
  - The cloned source at $SOURCE_DIR (delete with: rm -rf $SOURCE_DIR)

EOF

printf "Continue? [y/N] "
read -r REPLY </dev/tty || REPLY="n"
case "$REPLY" in
    y|Y|yes|YES) ;;
    *)
        echo "Aborted."
        exit 0
        ;;
esac

rm -rf "$SKILL_DIR"
echo "  removed $SKILL_DIR"

if [ -f "$USER_CLAUDE/settings.json" ]; then
    python3 - "$USER_CLAUDE/settings.json" <<'PY'
import sys, json
path = sys.argv[1]
try:
    data = json.load(open(path))
except (json.JSONDecodeError, FileNotFoundError):
    sys.exit(0)
hooks_block = data.get("hooks") or {}
ss = hooks_block.get("SessionStart", [])
filtered = []
for entry in ss:
    cmds = entry.get("hooks", []) or []
    if any("brain/sync.sh" in (c.get("command") or "") for c in cmds):
        continue
    filtered.append(entry)
if filtered != ss:
    if filtered:
        hooks_block["SessionStart"] = filtered
    else:
        hooks_block.pop("SessionStart", None)
    data["hooks"] = hooks_block
    json.dump(data, open(path, "w"), indent=2)
    print("  removed SessionStart sync hook from settings.json")
PY
fi

cat <<EOF

Done. Brain skill is uninstalled.

To clean per-project wiring (in each project that had /brain init run):
  rm -rf <project>/plugins/Brain
  # Then edit <project>/CLAUDE.md to remove the 'brain: <relative-path>' line

To delete the source repo:
  rm -rf $SOURCE_DIR
EOF

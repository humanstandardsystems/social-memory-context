#!/usr/bin/env bash
# update.sh — pull the latest brain skill and re-run install.
# Usage: bash update.sh

set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Pulling latest social-memory-context..."
git -C "$SOURCE_DIR" pull --rebase --autostash

echo ""
bash "$SOURCE_DIR/install.sh"

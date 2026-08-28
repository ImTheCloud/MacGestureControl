#!/bin/bash
# Fast build-and-run loop for development.
#
#   ./Scripts/dev.sh              rebuild and relaunch, streaming logs
#   ./Scripts/dev.sh -c release   same, optimised
#
# Grant Accessibility access to your terminal once (System Settings ->
# Privacy & Security -> Accessibility) and it survives every rebuild, which a
# freshly signed binary would not.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="debug"
if [[ "${1:-}" == "-c" && -n "${2:-}" ]]; then CONFIG="$2"; fi

# Replace any instance already running, including one started from dist/.
pkill -x MacGestureControl 2>/dev/null || true

swift build -c "$CONFIG"
BINARY="$(swift build -c "$CONFIG" --show-bin-path)/MacGestureControl"

echo "→ $BINARY   (ctrl-C to stop)"
exec "$BINARY"

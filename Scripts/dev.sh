#!/bin/bash
# Fast build-and-run loop for development.
#
#   ./Scripts/dev.sh              rebuild and relaunch, streaming logs
#   ./Scripts/dev.sh -c release   same, optimised
#
# Accessibility is granted to a signature, not to a name: `swift build` signs
# the binary ad-hoc, so every rebuild is a file the previous grant no longer
# covers and the app asks again while System Settings still shows it enabled.
# Set MACGESTURE_CODESIGN_IDENTITY to a self-signed code-signing certificate
# (see Scripts/build-app.sh) and the grant survives rebuilds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CONFIG="debug"
if [[ "${1:-}" == "-c" && -n "${2:-}" ]]; then CONFIG="$2"; fi

# Replace any instance already running, including one started from dist/.
pkill -x MacGestureControl 2>/dev/null || true

swift build -c "$CONFIG"
BINARY="$(swift build -c "$CONFIG" --show-bin-path)/MacGestureControl"

if [[ -n "${MACGESTURE_CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --sign "$MACGESTURE_CODESIGN_IDENTITY" "$BINARY"
fi

echo "→ $BINARY   (ctrl-C to stop)"
exec "$BINARY"

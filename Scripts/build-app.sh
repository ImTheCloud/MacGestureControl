#!/bin/bash
# Builds MacGestureControl.app into dist/.
#
# Running the bare binary works, but a real bundle is worth having: macOS ties
# Accessibility permission to the app rather than to your terminal, and
# "Launch at Login" can then use SMAppService instead of a LaunchAgent plist.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/dist/MacGestureControl.app"

cd "$ROOT"

# Universal (Apple Silicon + Intel) when the toolchain supports it.
BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)
if ! swift build "${BUILD_FLAGS[@]}"; then
    echo "Universal build unavailable, falling back to this machine's architecture."
    BUILD_FLAGS=(-c release)
    swift build "${BUILD_FLAGS[@]}"
fi

# Ask for the bin path using the same flags, otherwise this resolves to a
# different (single-architecture) product directory.
BINARY="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/MacGestureControl"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/MacGestureControl"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc signature: enough for the app to keep its Accessibility grant across
# rebuilds on the machine that built it.
codesign --force --sign - "$APP"

echo
echo "Built $APP"
echo "Move it to /Applications, launch it, then grant Accessibility access."

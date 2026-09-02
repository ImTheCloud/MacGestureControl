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

# The icon is generated art, kept in the repo so a build needs nothing but
# Swift. Regenerate it with: swift Scripts/make-icon.swift
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# macOS keys the Accessibility grant to the signature it was granted to, and an
# ad-hoc signature is different in every build — so each rebuild silently drops
# the permission while System Settings still lists the old entry, switched on.
# A self-signed certificate keeps the grant, because the requirement macOS
# stores then names the certificate rather than this exact file:
#
#   Keychain Access -> Certificate Assistant -> Create a Certificate...
#   name it, type "Code Signing", then
#   export MACGESTURE_CODESIGN_IDENTITY="that name"
IDENTITY="${MACGESTURE_CODESIGN_IDENTITY:--}"
codesign --force --sign "$IDENTITY" "$APP"

# A zip is what a GitHub release needs, and `ditto` keeps the bundle's
# structure and signature intact where `zip` would not.
ARCHIVE="$ROOT/dist/MacGestureControl.zip"
rm -f "$ARCHIVE"
ditto -c -k --keepParent "$APP" "$ARCHIVE"

echo
echo "Built $APP"
echo "      $ARCHIVE  (attach this to a release)"
echo "Move it to /Applications, launch it, then grant Accessibility access."
if [[ "$IDENTITY" == "-" ]]; then
    echo "Signed ad-hoc: re-grant Accessibility after every rebuild, or set"
    echo "MACGESTURE_CODESIGN_IDENTITY to a self-signed code-signing certificate."
fi

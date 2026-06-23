#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICON_DIR="$ROOT/frontend/src-tauri/gen/apple/Assets.xcassets/AppIcon.appiconset"
CACHE_DIR="${TMPDIR:-/tmp}/synday-swift-module-cache"

CLANG_MODULE_CACHE_PATH="$CACHE_DIR" \
SWIFT_MODULECACHE_PATH="$CACHE_DIR" \
  swift "$ROOT/scripts/strip-ios-icon-alpha.swift" "$ICON_DIR"

for icon in "$ICON_DIR"/*.png; do
  if [[ "$(sips -g hasAlpha "$icon" 2>/dev/null | tail -1 | awk '{print $2}')" != "no" ]]; then
    echo "iOS AppIcon still contains an alpha channel: $icon" >&2
    exit 1
  fi
done

echo "iOS AppIcon assets are RGB and ready for Apple validation."

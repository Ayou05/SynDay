#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

(
  cd "$ROOT/backend"
  export GOCACHE="$PWD/.cache/go-build"
  export GOMODCACHE="$PWD/.cache/go-mod"
  go test ./...
  go vet ./...
)

(
  cd "$ROOT/frontend"
  npm run build
)

(
  cd "$ROOT/frontend/src-tauri"
  export PATH="$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/bin:$PATH"
  cargo check
  cargo clippy --all-targets -- -D warnings
)

if command -v sips >/dev/null 2>&1; then
  for icon in "$ROOT"/frontend/src-tauri/gen/apple/Assets.xcassets/AppIcon.appiconset/*.png; do
    if [[ "$(sips -g hasAlpha "$icon" 2>/dev/null | tail -1 | awk '{print $2}')" != "no" ]]; then
      echo "iOS AppIcon contains an alpha channel: $icon" >&2
      exit 1
    fi
  done
fi

if command -v xmllint >/dev/null 2>&1; then
  xmllint --noout \
    "$ROOT/frontend/src-tauri/gen/apple/LaunchScreen.storyboard" \
    "$ROOT/frontend/src-tauri/gen/android/app/src/main/AndroidManifest.xml" \
    "$ROOT/frontend/src-tauri/gen/android/app/src/main/res/values/themes.xml" \
    "$ROOT/frontend/src-tauri/gen/android/app/src/main/res/values-night/themes.xml" \
    "$ROOT/frontend/src-tauri/gen/android/app/src/main/res/values-v31/themes.xml"
fi

(
  cd "$ROOT"
  git diff --check
)

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/scripts/dev-env.sh"

has_client_value() {
  local name="$1"
  [[ -n "${!name:-}" ]] || grep -Eq "^${name}=.+" "$ROOT/frontend/.env.production" 2>/dev/null
}

require_production_client_config() {
  local missing=()
  for name in VITE_API_BASE_URL VITE_SUPABASE_URL VITE_SUPABASE_PUBLISHABLE_KEY; do
    if ! has_client_value "$name"; then
      missing+=("$name")
    fi
  done
  if (( ${#missing[@]} > 0 )); then
    echo "missing production client configuration: ${missing[*]}" >&2
    echo "configure frontend/.env.production or export the variables before building" >&2
    exit 1
  fi
}

case "${1:-}" in
  android)
    require_production_client_config
    cd "$ROOT/frontend"
    npx tauri android build --debug --apk
    ;;
  ios)
    require_production_client_config
    "$ROOT/scripts/prepare-ios-assets.sh"
    cd "$ROOT/frontend"
    npx tauri ios build --no-sign --target aarch64 --ci
    ;;
  macos-preview)
    cd "$ROOT/frontend"
    VITE_PREVIEW_MODE=true npx tauri build --debug --bundles app
    ;;
  *)
    echo "usage: $0 android|ios|macos-preview" >&2
    exit 2
    ;;
esac

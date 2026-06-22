#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

(
  cd "$ROOT/backend"
  export GOCACHE="$PWD/.cache/go-build"
  export GOMODCACHE="$PWD/.cache/go-mod"
  go test ./...
)

(
  cd "$ROOT/frontend"
  npm run build
)

(
  cd "$ROOT/frontend/src-tauri"
  export PATH="$HOME/.rustup/toolchains/stable-aarch64-apple-darwin/bin:$PATH"
  cargo check
)

(
  cd "$ROOT"
  git diff --check
)

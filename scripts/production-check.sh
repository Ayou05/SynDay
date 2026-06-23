#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-https://api.synday.catclaw.cloud}"
SUPABASE_URL="${SUPABASE_URL:-https://abuhrrrqvpivzdvwkmik.supabase.co}"

check_json() {
  local path="$1"
  local expected="$2"
  local body
  body="$(curl --fail --silent --show-error --max-time 15 "$API_URL$path")"
  if [[ "$body" != *"$expected"* ]]; then
    echo "Unexpected response from $path: $body" >&2
    return 1
  fi
  echo "OK $path"
}

echo "Checking DNS and TLS for $API_URL"
curl --fail --silent --show-error --max-time 15 --output /dev/null "$API_URL/healthz"
check_json "/healthz" '"status":"ok"'
check_json "/readyz" '"status":"ready"'
check_json "/readyz" '"ai":true'
check_json "/readyz" '"realtime":true'
check_json "/v1/time" '"timezone":"Asia/Shanghai"'

echo "Checking Supabase Auth reachability"
curl --fail --silent --show-error --max-time 15 --output /dev/null "$SUPABASE_URL/auth/v1/health"

echo "Production public endpoints are reachable."

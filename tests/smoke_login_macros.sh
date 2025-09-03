#!/usr/bin/env bash
set -euo pipefail

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need ibmcloud
need jq

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")"/.. && pwd)"

GUID_011="62794a08a0e5417d9e5b18a18aba3c01"
GUID_128="0bc27b84373c4d88b40c98dbc3690c21"

run_and_check() {
  local script="$1" expected="$2" label="$3"
  "$script" us-south >/dev/null
  sleep 1
  local got
  got="$(ibmcloud target --output json 2>/dev/null | jq -r '.account.guid // empty')"
  if [[ "$got" == "$expected" ]]; then
    printf '\033[32m✔ %s -> %s\033[0m\n' "$label" "$got"
  else
    printf '\033[31m✘ %s -> got %s, expected %s\033[0m\n' "$label" "$got" "$expected" >&2
    exit 1
  fi
}

run_and_check "$ROOT_DIR/scripts/ibm-login-011.sh" "$GUID_011" "011 sandbox"
run_and_check "$ROOT_DIR/scripts/ibm-login-128.sh" "$GUID_128" "128 eposit"

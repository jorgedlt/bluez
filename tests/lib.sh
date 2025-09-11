#!/usr/bin/env bash
# tests/lib.sh — shared helpers for bluez smoke tests

set -euo pipefail

# Pretty output
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
note() { printf '\033[36m%s\033[0m\n' "$*"; }    # cyan
ok()   { printf '\033[32m✔ %s\033[0m\n' "$*"; }  # green
err()  { printf '\033[31m✘ %s\033[0m\n' "$*" >&2; }

# Section headers
section() { printf "\n== %s ==\n" "$*"; }

# Command runner (always show command, capture exit)
run() {
  printf "\n$ %s\n" "$*"
  if "$@"; then
    ok "$*"
  else
    err "$* failed"
    return 1
  fi
}

# Hard requirement: command must exist
need() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Missing dependency: $1"
    exit 1
  }
}

# Quick assertions
assert_nonempty() {
  local label="$1"; shift
  if [[ -z "${1:-}" || "$1" == "null" ]]; then
    err "Expected non-empty: $label"
    return 1
  fi
}

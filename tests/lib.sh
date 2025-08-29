#!/usr/bin/env bash
# Shared helpers for repo smoke tests
set -euo pipefail

# Pretty output
bold() { printf '\033[1m%s\033[0m\n' "$*"; }
note() { printf '\033[36m%s\033[0m\n' "$*"; }    # cyan
ok()   { printf '\033[32m✔ %s\033[0m\n' "$*"; }  # green
err()  { printf '\033[31m✘ %s\033[0m\n' "$*" >&2; }

# Require a function or abort
need_fn() {
  local fn="$1"
  if ! type -t "$fn" >/dev/null 2>&1; then
    err "Missing function: $fn (did you 'source ./loader.sh'?)"
    exit 1
  fi
}

# Quick assertion helpers (non-fatal unless -e set)
assert_nonempty() {
  local label="$1" ; shift
  if [[ -z "${1:-}" || "$1" == "null" ]]; then
    err "Expected non-empty: ${label}"
    return 1
  fi
}

# Are we logged in?
ensure_logged_in() {
  if ! ibmcloud target >/dev/null 2>&1; then
    err "Not logged in. Run:  source ./loader.sh && ibmlogin"
    exit 1
  fi
}

# Random name (safe for RG names)
rand_name() {
  local prefix="${1:-tmp}"
  printf '%s-%s' "$prefix" "$(date +%s)"
}

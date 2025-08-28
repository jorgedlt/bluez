#!/usr/bin/env bash
# tests/smoke_helpers.sh
# Define minimal helpers for smoke tests ONLY if they don't already exist.

# shellcheck disable=SC2317  # allow functions guarded by existence checks

if ! declare -F section >/dev/null 2>&1; then
section() {
  printf "\n== %s ==\n" "$*"
}
fi

if ! declare -F note >/dev/null 2>&1; then
note() {
  printf -- "-- %s\n" "$*"
}
fi

if ! declare -F need >/dev/null 2>&1; then
need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    exit 1
  }
}
fi

if ! declare -F run >/dev/null 2>&1; then
run() {
  printf "\n$ %s\n" "$*"
  "$@"
}
fi

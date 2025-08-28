#!/usr/bin/env bash
# loader.sh — central loader for Bluez shell helpers
# Scope:
#   - Resolves repo root and sources init.sh, then all files in functions/
#   - Idempotent: safe to source multiple times
#   - Strict mode is OPT-IN (set STRICT=1 before sourcing)
#
# Usage:
#   source ./loader.sh
#   # or from anywhere:
#   source /path/to/repo/loader.sh
#
# Notes:
#   - Only enables 'set -euo pipefail' if STRICT is set in the environment.
#   - Prints concise errors to stderr and returns non-zero on failure.

# ---- Optional strict mode (opt-in) -----------------------------------------
if [[ -n "${STRICT:-}" ]]; then
  set -euo pipefail
  IFS=$'\n\t'
fi

# ---- Idempotency guard -----------------------------------------------------
if [[ -n "${__BLUEZ_LOADER_ONCE__:-}" ]]; then
  # Already loaded in this shell
  return 0
fi
declare -g __BLUEZ_LOADER_ONCE__=1

# ---- Resolve repo root (works from any cwd) --------------------------------
# shellcheck disable=SC2292
__bluez_loader_src="${BASH_SOURCE[0]:-${(%):-%x}}"
__bluez_repo_root="$( cd "$( dirname "$__bluez_loader_src" )" && pwd )"

# ---- Small echo helper (stderr by default) ---------------------------------
__loader_log() { printf '%s\n' "[loader] $*" >&2; }

# ---- Pre-flight: required tools? (soft check; fail nicely) -----------------
__need_tool() {
  command -v "$1" >/dev/null 2>&1 || { __loader_log "Missing dependency: $1"; return 1; }
}

# We don’t force these, but many functions will need them:
# __need_tool ibmcloud || return 1
# __need_tool jq       || return 1

# ---- Source init.sh first --------------------------------------------------
if [[ ! -f "$__bluez_repo_root/init.sh" ]]; then
  __loader_log "init.sh not found at $__bluez_repo_root/init.sh"
  return 1
fi
# shellcheck source=/dev/null
source "$__bluez_repo_root/init.sh"

# ---- Source every *.sh under functions/ in stable order --------------------
__func_dir="$__bluez_repo_root/functions"
if [[ -d "$__func_dir" ]]; then
  # predictable alphabetical order
  while IFS= read -r -d '' f; do
    # skip hidden or non-readable files just in case
    [[ -r "$f" ]] || continue
    # shellcheck source=/dev/null
    source "$f"
  done < <(find "$__func_dir" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
else
  __loader_log "functions/ directory not found at $__func_dir"
fi

__loader_log "IBM Cloud toolkit loaded from $__bluez_repo_root"
unset __bluez_loader_src __bluez_repo_root __func_dir

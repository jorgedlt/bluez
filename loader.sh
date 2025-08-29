#!/usr/bin/env bash
# loader.sh — centralized loader for bluez bash toolkit

# BLUEZ_LOADER_VERBOSE=1 source ./loader.sh --force

# Resolve repo root even when sourced from elsewhere
BLUEZ_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Optional verbosity: export BLUEZ_LOADER_VERBOSE=1 to see what gets sourced
BLUEZ_LOADER_VERBOSE="${BLUEZ_LOADER_VERBOSE:-}"

# Support --force to reload in an already-sourced shell
if [[ "${1:-}" == "--force" ]]; then
  unset -v BLUEZ_LOADER_LOADED
fi

# Idempotency guard
if [[ -n "${BLUEZ_LOADER_LOADED:-}" ]]; then
  return 0
fi
BLUEZ_LOADER_LOADED=1

# Small helper
__bluez_log() {
  [[ -n "$BLUEZ_LOADER_VERBOSE" ]] && printf '[loader] %s\n' "$*" 1>&2
}

# 1) Source init.sh first
if [[ -r "${BLUEZ_ROOT}/init.sh" ]]; then
  __bluez_log "sourcing init.sh"
  # shellcheck source=/dev/null
  source "${BLUEZ_ROOT}/init.sh"
else
  printf 'loader: missing %s/init.sh\n' "$BLUEZ_ROOT" 1>&2
  return 1
fi

# 2) Source every module in functions/ (sorted)
if [[ -d "${BLUEZ_ROOT}/functions" ]]; then
  # Collect .sh files (non-recursive), sort by filename
  mapfile -t __bluez_files < <(find "${BLUEZ_ROOT}/functions" -maxdepth 1 -type f -name '*.sh' -print | LC_ALL=C sort)
  for __f in "${__bluez_files[@]}"; do
    __bluez_log "sourcing $(basename "$__f")"
    # shellcheck source=/dev/null
    source "$__f"
  done
else
  printf 'loader: missing %s/functions directory\n' "$BLUEZ_ROOT" 1>&2
  return 1
fi

# 3) Friendly one-liner when not verbose (optional; keep minimal)
[[ -z "$BLUEZ_LOADER_VERBOSE" ]] && printf '[loader] IBM Cloud toolkit loaded from %s\n' "$BLUEZ_ROOT" 1>&2

# Keep env noise low
unset -v __bluez_files __f

######################################

# # loader.sh
# #!/usr/bin/env bash
# # loader.sh — central loader for Bluez shell helpers

# # Idempotent load unless LOADER_FORCE=1 is set
# if [[ -n "${BLUEZ_LOADER_LOADED:-}" && -z "${LOADER_FORCE:-}" ]]; then
#   return 0
# fi
# BLUEZ_LOADER_LOADED=1

# # Strict mode is OPT-IN: set STRICT=1 before sourcing if you want -euo pipefail.

# # ---- Optional strict mode (opt-in) -----------------------------------------
# if [[ -n "${STRICT:-}" ]]; then
#   set -euo pipefail
#   IFS=$'\n\t'
# fi

# # ---- Idempotency guard -----------------------------------------------------
# if [[ -n "${__BLUEZ_LOADER_ONCE__:-}" ]]; then
#   return 0
# fi
# declare -g __BLUEZ_LOADER_ONCE__=1

# # ---- Resolve repo root (works from any cwd) --------------------------------
# # shellcheck disable=SC2292
# __bluez_loader_src="${BASH_SOURCE[0]:-${(%):-%x}}"
# __bluez_repo_root="$( cd "$( dirname "$__bluez_loader_src" )" && pwd )"

# # ---- Small echo helper (stderr by default) ---------------------------------
# __loader_log() { printf '%s\n' "[loader] $*" >&2; }

# # ---- Source init.sh first --------------------------------------------------
# if [[ ! -f "$__bluez_repo_root/init.sh" ]]; then
#   __loader_log "init.sh not found at $__bluez_repo_root/init.sh"
#   return 1
# fi
# # shellcheck source=/dev/null
# source "$__bluez_repo_root/init.sh"

# # ---- Source every *.sh under functions/ in stable order --------------------
# __func_dir="$__bluez_repo_root/functions"
# if [[ -d "$__func_dir" ]]; then
#   while IFS= read -r -d '' f; do
#     [[ -r "$f" ]] || continue
#     # shellcheck source=/dev/null
#     source "$f"
#   done < <(find "$__func_dir" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
# else
#   __loader_log "functions/ directory not found at $__func_dir"
# fi

# __loader_log "IBM Cloud toolkit loaded from $__bluez_repo_root"
# unset __bluez_loader_src __bluez_repo_root __func_dir

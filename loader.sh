#!/usr/bin/env bash
# loader.sh — central loader for Bluez shell helpers

# Always verbose by default
: "${BLUEZ_LOADER_VERBOSE:=1}"

# --- colors ---
RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
GRAY=$'\033[90m'; RESET=$'\033[0m'

# --- logger with colors ---
bluez_log() {
  local level="${1:-info}"; shift
  local msg="$*"
  case "$level" in
    info)  [[ $BLUEZ_LOADER_VERBOSE -eq 1 ]] && printf "${GRAY}[loader] %s${RESET}\n" "$msg" ;;
    ok)    printf "${GREEN}[loader] %s${RESET}\n" "$msg" ;;
    warn)  printf "${YELLOW}[loader] %s${RESET}\n" "$msg" ;;
    err)   printf "${RED}[loader] %s${RESET}\n" "$msg" >&2 ;;
  esac
}

# 1) source init.sh first
if [[ -r "${BLUEZ_ROOT:-$(pwd)}/init.sh" ]]; then
  bluez_log info "sourcing init.sh"
  # shellcheck source=/dev/null
  source "${BLUEZ_ROOT:-$(pwd)}/init.sh"
else
  bluez_log err "missing ${BLUEZ_ROOT:-$(pwd)}/init.sh"
  return 1
fi

# 2) source every module in functions/ (sorted)
if [[ -d "${BLUEZ_ROOT:-$(pwd)}/functions" ]]; then
  mapfile -t _bluez_files < <(find "${BLUEZ_ROOT:-$(pwd)}/functions" -maxdepth 1 -type f -name '*.sh' | sort)
  for _f in "${_bluez_files[@]}"; do
    bluez_log info "sourcing $(basename "$_f")"
    # shellcheck source=/dev/null
    source "$_f"
  done
else
  bluez_log err "missing ${BLUEZ_ROOT:-$(pwd)}/functions directory"
  return 1
fi

unset _bluez_files

# Always print this footer
bluez_log ok "all helpers loaded"

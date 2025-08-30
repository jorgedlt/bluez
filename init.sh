#!/usr/bin/env bash
# init.sh — shared config, helpers, table printer, colors

# ===== Defaults =====
: "${IBMC_API_ENDPOINT:=https://cloud.ibm.com}"
: "${IBMC_REGION:=us-south}"
: "${IBMC_RG:=default}"
: "${IBMC_DEFAULT:=sandbox}"

# Per-account keyfiles, update paths as needed
: "${IBMC_KEYFILE_SANDBOX:=$HOME/ibmcloud_api_key_sandbox.json}"   # SandboxAccnt 62794a08…  IMS 3127011
: "${IBMC_KEYFILE_EPOSIT:=$HOME/ibmcloud_api_key.json}"            # EpositBox     0bc27b84…  IMS 2617128

# ===== Colors (for output) =====
RESET=$'\033[0m'
BOLD=$'\033[1m'

RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
MAGENTA=$'\033[35m'
CYAN=$'\033[36m'
GRAY=$'\033[90m'

# ===== Color helpers =====
c_err()  { printf "%s%s%s\n" "${RED}"    "$*" "${RESET}" >&2; }
c_warn() { printf "%s%s%s\n" "${YELLOW}" "$*" "${RESET}" >&2; }
c_ok()   { printf "%s%s%s\n" "${GREEN}"  "$*" "${RESET}"; }
c_note() { printf "%s%s%s\n" "${GRAY}"   "$*" "${RESET}"; }
c_hdr()  { printf "%s%s%s\n" "${BOLD}${CYAN}" "$*" "${RESET}"; }

# ===== Tiny deps =====
_need() { command -v "$1" >/dev/null 2>&1 || { c_err "Missing dependency: $1"; return 1; }; }

# ===== Region / RG guards =====
_ensure_region() {
  local r
  r="${1:-$IBMC_REGION}"
  [[ -n "$r" ]] || return 0
  ibmcloud target -r "$r" >/dev/null 2>&1 || true
}

_ensure_rg() {
  local g
  g="${1:-$IBMC_RG}"
  [[ -n "$g" ]] || return 0
  if ibmcloud resource groups --output json 2>/dev/null | jq -e --arg rg "$g" '.[] | select(.name==$rg)' >/dev/null; then
    ibmcloud target -g "$g" >/dev/null 2>&1 || true
  fi
}

# ===== JSON key reader =====
_read_key() {
  local f
  f="$1"
  [[ -f "$f" ]] || { c_err "API key file not found: $f"; return 1; }
  jq -r '.apikey // empty' "$f" | awk 'NF' || { c_err "No apikey in $f"; return 1; }
}

# ===== Robust keyfile resolver =====
# Accepts: nickname, account name, IMS id, GUID, or a readable *.json path
_keyfile_for() {
  local sel
  sel="$1"

  # explicit path
  if [[ "$sel" == */* || "$sel" == *.json ]]; then
    if [[ -r "$sel" ]]; then
      printf '%s\n' "$sel"
      return 0
    fi
  fi

  # normalize for matching
  local norm
  norm="$(printf '%s' "$sel" | tr '[:upper:]' '[:lower:]')"
  norm="${norm//[^a-z0-9]/}"   # keep [a-z0-9]

  case "$norm" in
    # Sandbox account aliases
    sandbox|sandboxaccnt|3127011|62794a08a0e5417d9e5b18a18aba3c01)
      printf '%s\n' "$IBMC_KEYFILE_SANDBOX"; return 0 ;;
    # Eposit account aliases
    eposit|epositbox|2617128|0bc27b84373c4d88b40c98dbc3690c21)
      printf '%s\n' "$IBMC_KEYFILE_EPOSIT"; return 0 ;;
  esac

  # environment override like IBMC_KEYFILE_<NAME>
  local var
  var="IBMC_KEYFILE_$(printf '%s' "$sel" | tr '[:lower:]' '[:upper:]' | tr -cd 'A-Z0-9_')"
  if [[ -n "${!var:-}" ]]; then
    printf '%s\n' "${!var}"
    return 0
  fi

  # default fallback
  printf '%s\n' "$IBMC_KEYFILE_SANDBOX"
}

# ===== small table printer (used by devops, etc.) =====
_print_table() {
  local header widths
  header="$1"
  widths="$2"

  local IFS=$'\t'
  local cols
  read -r -a cols <<<"$header"

  IFS=',' read -r -a w <<<"$widths"

  # header (cyan + bold)
  {
    for i in "${!cols[@]}"; do
      printf "%s%-*s%s%s" "${BOLD}${CYAN}" "${w[i]}" "${cols[i]}" "${RESET}" \
        $([[ $i -lt $((${#cols[@]}-1)) ]] && printf "  ")
    done
    printf "\n"
  } 1>&1

  # rows (plain)
  while IFS=$'\t' read -r -a r; do
    for i in "${!r[@]}"; do
      printf "%-*s%s" "${w[i]}" "${r[i]}" \
        $([[ $i -lt $((${#r[@]}-1)) ]] && printf "  ")
    done
    printf "\n"
  done
}

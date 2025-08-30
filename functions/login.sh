#!/usr/bin/env bash
# login.sh, login and account helpers

: "${RED:=$'\033[31m'}"
: "${GREEN:=$'\033[32m'}"
: "${YELLOW:=$'\033[33m'}"
: "${CYAN:=$'\033[36m'}"
: "${BOLD:=$'\033[1m'}"
: "${RESET:=$'\033[0m'}"

if ! declare -F _need >/dev/null 2>&1; then
  _need() { command -v "$1" >/dev/null 2>&1 || { printf "%sMissing dependency: %s%s\n" "$RED" "$1" "$RESET" >&2; return 1; }; }
fi

if ! declare -F _keyfile_for >/dev/null 2>&1; then
  _keyfile_for() {
    local sel="$1"
    if [[ "$sel" == */* || "$sel" == *.json ]]; then
      [[ -r "$sel" ]] && { printf '%s\n' "$sel"; return 0; }
    fi
    printf '%s\n' "${IBMC_KEYFILE_SANDBOX:-$HOME/ibmcloud_api_key_sandbox.json}"
  }
fi

: "${IBMC_API_ENDPOINT:=https://cloud.ibm.com}"
: "${IBMC_REGION:=us-south}"
: "${IBMC_RG:=default}"
: "${IBMC_DEFAULT:=sandbox}"

# Usage: ibmlogin [key-or-alias] [--region REGION] [--rg GROUP]
ibmlogin() {
  _need ibmcloud || return 1
  local sel="" region="" rg=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --region) region="$2"; shift 2 ;;
      --rg)     rg="$2";     shift 2 ;;
      *)        sel="$1";    shift    ;;
    esac
  done

  local keyf
  if [[ -n "$sel" ]]; then
    keyf="$(_keyfile_for "$sel")"
  else
    keyf="$(_keyfile_for "$IBMC_DEFAULT")"
  fi
  if [[ ! -r "$keyf" ]]; then
    printf "%sKey file not readable: %s%s\n" "${RED}" "$keyf" "${RESET}" >&2
    return 1
  fi

  echo "Logging in with key: $keyf"
  ibmcloud login -a "${IBMC_API_ENDPOINT}" --apikey @"$keyf" -q || return 1

  [[ -n "$region" ]] || region="$IBMC_REGION"
  [[ -n "$rg"     ]] || rg="$IBMC_RG"
  [[ -n "$region" ]] && ibmcloud target -r "$region" || true
  [[ -n "$rg"     ]] && ibmcloud target -g "$rg"     || true
  ibmwhoami
}

# Usage: ibmwhoami
# Parses plain `ibmcloud target` output for maximum compatibility across CLI versions.
ibmwhoami() {
  _need ibmcloud || return 1
  local t; t="$(ibmcloud target 2>/dev/null || true)"
  if [[ -z "$t" ]]; then
    printf "%sNot logged in.%s\n" "$YELLOW" "$RESET" >&2
    return 1
  fi

  # Extract fields from the standard human-readable output
  local api region user account rg
  api="$(awk -F': *' '/^API endpoint:/ {print $2}' <<<"$t")"
  region="$(awk -F': *' '/^Region:/ {print $2}' <<<"$t")"
  user="$(awk -F': *' '/^User:/ {print $2}' <<<"$t")"
  account="$(awk -F': *' '/^Account:/ {print $2}' <<<"$t")"
  rg="$(awk -F': *' '/^Resource group:/ {print $2}' <<<"$t")"

  # Normalize empty values
  [[ -n "$api"    ]] || api="unknown"
  [[ -n "$region" ]] || region="unknown"
  [[ -n "$user"   ]] || user="unknown"
  [[ -n "$account" ]] || account="unknown"
  if [[ -z "$rg" || "$rg" =~ ^No\ resource\ group\ targeted ]]; then
    rg="none"
  fi

  printf "%sAPI endpoint:%s %s\n"     "${BOLD}${CYAN}" "${RESET}" "$api"
  printf "%sRegion:%s       %s\n"     "${BOLD}${CYAN}" "${RESET}" "$region"
  printf "%sUser:%s         %s\n"     "${BOLD}${CYAN}" "${RESET}" "$user"
  printf "%sAccount:%s      %s\n"     "${BOLD}${CYAN}" "${RESET}" "$account"
  printf "%sResource group:%s %s\n"   "${BOLD}${CYAN}" "${RESET}" "$rg"
}

# Usage: ibmaccls
# Uses the CLI's built-in table output to avoid JSON shape drift.
ibmaccls() {
  _need ibmcloud || return 1
  ibmcloud account list
}

# Usage: ibmaccswap <acctName|guid|keyfile>
ibmaccswap() {
  _need ibmcloud || return 1
  local sel="$1"
  if [[ -z "$sel" ]]; then
    echo "Usage: ibmaccswap <acctName|guid|keyfile>" >&2
    return 1
  fi

  local keyf
  keyf="$(_keyfile_for "$sel")"
  if [[ ! -r "$keyf" ]]; then
    echo "${RED}No usable keyfile for $sel${RESET}" >&2
    return 1
  fi

  echo "Swapping account using keyfile: $keyf"
  ibmcloud login --apikey @"$keyf" -q || return 1
  ibmwhoami
}

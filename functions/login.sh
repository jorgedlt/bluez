#!/usr/bin/env bash
# login.sh, login and account helpers

: "${RED:=$'\033[31m'}"
: "${GREEN:=$'\033[32m'}"
: "${YELLOW:=$'\033[33m'}"
: "${CYAN:=$'\033[36m'}"
: "${BOLD:=$'\033[1m'}"
: "${RESET:=$'\033[0m'}"

# Provide _need if init.sh was not sourced
if ! declare -F _need >/dev/null 2>&1; then
  _need() { command -v "$1" >/dev/null 2>&1 || { printf "%sMissing dependency: %s%s\n" "$RED" "$1" "$RESET" >&2; return 1; }; }
fi

# Fallback for _keyfile_for and defaults if init.sh was not sourced
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
ibmwhoami() {
  _need jq || return 1
  ibmcloud target --output json 2>/dev/null | jq -r '
    "API endpoint: \(.api_endpoint)\n" +
    "Region:       \(.region)\n" +
    "User:         \(.user.email)\n" +
    "Account:      \(.account.name) (\(.account.guid)) <-> \(.account.bluemix_subscriptions[0].ims_account_id)\n" +
    "Resource group: " + (.resource_group.name // "none")
  ' | sed -E \
      -e "s/^API endpoint:/${BOLD}${CYAN}&${RESET}/" \
      -e "s/^Region:/${BOLD}${CYAN}&${RESET}/" \
      -e "s/^User:/${BOLD}${CYAN}&${RESET}/" \
      -e "s/^Account:/${BOLD}${CYAN}&${RESET}/" \
      -e "s/^Resource group:/${BOLD}${CYAN}&${RESET}/"
}

# Usage: ibmaccls
ibmaccls() {
  _need jq || return 1
  ibmcloud account list --output json | jq -r '
    (["Name","AccountID","State","Owner"] | @tsv),
    (.[] | [.name,.account_id,.state,.owner_ibmid] | @tsv)
  ' | column -t -s$'\t'
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

  local acctN acctI
  acctN="$(ibmcloud target --output json | jq -r '.account.name')"
  acctI="$(ibmcloud target --output json | jq -r '.account.guid')"

  echo "${GREEN}Switched account:${RESET} ${BOLD}${acctN}${RESET} (${acctI})"
  ibmwhoami
}

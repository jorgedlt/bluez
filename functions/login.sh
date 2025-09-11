#!/usr/bin/env bash
# functions/login.sh — IBM Cloud login & account switching helpers

# ---------- colors ----------
: "${RED:=$'\033[31m'}"
: "${GREEN:=$'\033[32m'}"
: "${YELLOW:=$'\033[33m'}"
: "${CYAN:=$'\033[36m'}"
: "${BOLD:=$'\033[1m'}"
: "${RESET:=$'\033[0m'}"

# ---------- deps ----------
if ! declare -F _need >/dev/null 2>&1; then
  _need() { command -v "$1" >/dev/null 2>&1 || { printf "%sMissing dependency: %s%s\n" "$RED" "$1" "$RESET" >&2; return 1; }; }
fi

# ---------- defaults ----------
: "${IBMC_API_ENDPOINT:=https://cloud.ibm.com}"
: "${IBMC_REGION:=us-south}"
: "${IBMC_RG:=default}"       # default RG enforced
: "${IBMC_DEFAULT:=sandbox}"  # default alias -> sandbox (011)

# ---------- keyfile resolver ----------
_keyfile_for() {
  local sel="$1"; [[ -n "$sel" ]] || return 1

  if [[ "$sel" == */* || "$sel" == *.json ]]; then
    [[ -r "$sel" ]] && { printf '%s\n' "$sel"; return 0; }
  fi

  local H="$HOME"
  local k_legacy="$H/ibmcloud_key_legacy-128.json"
  local k_sbx="$H/ibmcloud_key_sandbox-011.json"
  local k_alpha="$H/ibmcloud_key_DevAlpha-729.json"
  local k_beta="$H/ibmcloud_key_DevBeta-651.json"
  local k_gamma="$H/ibmcloud_key_DevGamma-773.json"

  local t="${sel,,}"; t="${t//[^a-z0-9]/}"

  declare -A MAP=(
    [legacy]="$k_legacy" [128]="$k_legacy" [epositbox]="$k_legacy"
    [sandbox]="$k_sbx"   [011]="$k_sbx"    [sandboxaccnt]="$k_sbx"
    [devalpha]="$k_alpha" [sandboxdevalpha]="$k_alpha" [729]="$k_alpha"
    [devbeta]="$k_beta"   [sandboxdevbeta]="$k_beta"   [651]="$k_beta"
    [devgamma]="$k_gamma" [sandboxdevgamma]="$k_gamma" [773]="$k_gamma"
  )
  if [[ -n "${MAP[$t]:-}" && -r "${MAP[$t]}" ]]; then
    printf '%s\n' "${MAP[$t]}"; return 0
  fi

  if [[ "$t" =~ ^[0-9]{3}$ ]]; then
    local g; g="$(ls "$H"/ibmcloud_key_*-"$t".json 2>/dev/null | head -n1)"
    [[ -r "$g" ]] && { printf '%s\n' "$g"; return 0; }
  fi

  return 1
}

# ---------- commands ----------
ibmlogin() {
  _need ibmcloud || return 1
  local sel="" region="${IBMC_REGION}" rg="${IBMC_RG}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --region) region="$2"; shift 2 ;;
      --rg)     rg="$2";     shift 2 ;;
      *)        sel="$1";    shift    ;;
    esac
  done

  local keyf
  keyf="$(_keyfile_for "${sel:-${IBMC_DEFAULT}}")" \
    || { printf "%sNo usable keyfile for '%s'%s\n" "$RED" "${sel:-${IBMC_DEFAULT}}" "$RESET" >&2; return 1; }

  echo "Logging in with key: $keyf"
  IBMCLOUD_COLOR=false ibmcloud login -a "$IBMC_API_ENDPOINT" -r "$region" --apikey @"$keyf" -q || return 1
  ibmcloud target -g "$rg" >/dev/null 2>&1 || true
  ibmwhoami
}

ibmaccswap() {
  _need ibmcloud || return 1
  local sel="$1"
  [[ -n "$sel" ]] || { echo "Usage: ibmaccswap <acctName|alias|IMS-last3|keyfile>" >&2; return 1; }

  local keyf
  keyf="$(_keyfile_for "$sel")" || { echo "${RED}No usable keyfile for $sel${RESET}" >&2; return 1; }

  echo "Swapping account using keyfile: $keyf"
  IBMCLOUD_COLOR=false ibmcloud login --apikey @"$keyf" -q || return 1
  ibmcloud target -r "$IBMC_REGION" >/dev/null 2>&1 || true
  ibmcloud target -g "$IBMC_RG"     >/dev/null 2>&1 || true
  ibmwhoami
}

ibmaccls() {
  _need ibmcloud || return 1
  ibmcloud account list
}

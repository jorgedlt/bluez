#!/usr/bin/env bash
# functions/login.sh — IBM Cloud login & account switching helpers
# - Resolves keyfiles by friendly name, IMS last-3, or path (no full GUIDs in code)
# - Always passes region on login to avoid interactive prompt
# - Provides ibmlogin, ibmaccswap, ibmaccls, ibmwhoami

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
: "${IBMC_RG:=}"
: "${IBMC_DEFAULT:=sandbox}"   # default alias -> sandbox (011)

# ---------- keyfile resolver (no full GUIDs) ----------
# Usage: _keyfile_for <acctName|alias|IMS-last3|keyfile>
_keyfile_for() {
  local sel="$1"; [[ -n "$sel" ]] || return 1

  # direct path / file
  if [[ "$sel" == */* || "$sel" == *.json ]]; then
    [[ -r "$sel" ]] && { printf '%s\n' "$sel"; return 0; }
  fi

  local H="$HOME"
  local k_legacy="$H/ibmcloud_key_legacy-128.json"
  local k_sbx="$H/ibmcloud_key_sandbox-011.json"
  local k_alpha="$H/ibmcloud_key_DevAlpha-729.json"
  local k_beta="$H/ibmcloud_key_DevBeta-651.json"
  local k_gamma="$H/ibmcloud_key_DevGamma-773.json"

  # normalize token (case/space/dash/underscore insensitive)
  local t="${sel,,}"; t="${t//[^a-z0-9]/}"

  # aliases (friendly names + IMS last-3) — keep short, no GUIDs
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

  # IMS last-3 fallback (patterned filenames)
  if [[ "$t" =~ ^[0-9]{3}$ ]]; then
    local g; g="$(ls "$H"/ibmcloud_key_*-"$t".json 2>/dev/null | head -n1)"
    [[ -r "$g" ]] && { printf '%s\n' "$g"; return 0; }
  fi

  return 1
}

# ---------- commands ----------
# Usage: ibmlogin [alias|path.json] [--region REGION] [--rg GROUP]
ibmlogin() {
  _need ibmcloud || return 1
  local sel="" region="${IBMC_REGION:-us-south}" rg="${IBMC_RG:-}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --region) region="$2"; shift 2 ;;
      --rg)     rg="$2";     shift 2 ;;
      *)        sel="$1";    shift    ;;
    esac
  done

  local keyf
  keyf="$(_keyfile_for "${sel:-${IBMC_DEFAULT:-sandbox}}")" \
    || { printf "%sNo usable keyfile for '%s'%s\n" "$RED" "${sel:-${IBMC_DEFAULT:-sandbox}}" "$RESET" >&2; return 1; }

  echo "Logging in with key: $keyf"
  IBMCLOUD_COLOR=false ibmcloud login -a "$IBMC_API_ENDPOINT" -r "$region" --apikey @"$keyf" -q || return 1
  [[ -n "$rg" ]] && ibmcloud target -g "$rg" >/dev/null 2>&1 || true
  ibmwhoami
}

# Usage: ibmaccswap <acctName|alias|IMS-last3|keyfile>
ibmaccswap() {
  _need ibmcloud || return 1
  local sel="$1"
  [[ -n "$sel" ]] || { echo "Usage: ibmaccswap <acctName|alias|IMS-last3|keyfile>" >&2; return 1; }

  local keyf
  keyf="$(_keyfile_for "$sel")" || { echo "${RED}No usable keyfile for $sel${RESET}" >&2; return 1; }

  echo "Swapping account using keyfile: $keyf"
  IBMCLOUD_COLOR=false ibmcloud login --apikey @"$keyf" -q || return 1
  [[ -n "${IBMC_REGION:-}" ]] && ibmcloud target -r "$IBMC_REGION" >/dev/null 2>&1 || true
  [[ -n "${IBMC_RG:-}"     ]] && ibmcloud target -g "$IBMC_RG"     >/dev/null 2>&1 || true
  ibmwhoami
}

# Usage: ibmaccls
ibmaccls() {
  _need ibmcloud || return 1
  ibmcloud account list
}

# Usage: ibmwhoami
# Parses human-readable `ibmcloud target` (works even when JSON is flaky)
ibmwhoami() {
  _need ibmcloud || return 1
  local t; t="$(ibmcloud target 2>/dev/null || true)"
  if [[ -z "$t" ]]; then
    printf "%sNot logged in.%s\n" "$YELLOW" "$RESET" >&2
    return 1
  fi

  local api region user account rg
  api="$(awk -F': *' '/^API endpoint:/ {print $2}' <<<"$t")"
  region="$(awk -F': *' '/^Region:/ {print $2}' <<<"$t")"
  user="$(awk -F': *' '/^User:/ {print $2}' <<<"$t")"
  account="$(awk -F': *' '/^Account:/ {print $2}' <<<"$t")"
  rg="$(awk -F': *' '/^Resource group:/ {print $2}' <<<"$t")"

  [[ -n "$api"    ]] || api="unknown"
  [[ -n "$region" ]] || region="unknown"
  [[ -n "$user"   ]] || user="unknown"
  [[ -n "$account" ]] || account="unknown"
  if [[ -z "$rg" || "$rg" =~ ^No\ resource\ group\ targeted ]]; then rg="none"; fi

  printf "%sAPI endpoint:%s %s\n"   "${BOLD}${CYAN}" "${RESET}" "$api"
  printf "%sRegion:%s       %s\n"   "${BOLD}${CYAN}" "${RESET}" "$region"
  printf "%sUser:%s         %s\n"   "${BOLD}${CYAN}" "${RESET}" "$user"
  printf "%sAccount:%s      %s\n"   "${BOLD}${CYAN}" "${RESET}" "$account"
  printf "%sResource group:%s %s\n" "${BOLD}${CYAN}" "${RESET}" "$rg"
}

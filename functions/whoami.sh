#!/usr/bin/env bash
# whoami.sh — robust account/target reporting

: "${CYAN:=$'\033[36m'}"
: "${BOLD:=$'\033[1m'}"
: "${YELLOW:=$'\033[33m'}"
: "${RESET:=$'\033[0m'}"

_need() { command -v "$1" >/dev/null 2>&1; }

_mask() {
  local s="$1"; local n=${#s}
  ((n<=8)) && printf "%s" "$s" || printf "%s...%s" "${s:0:4}" "${s: -4}"
}

ibmwhoami() {
  _need ibmcloud || return 1

  # prefer JSON target output
  local j; j="$(ibmcloud target --output json 2>/dev/null || true)"
  if [[ -n "$j" ]]; then
    local api region user acct_name acct_guid acct_id rg
    api=$(jq -r '.api_endpoint // empty' <<<"$j")
    region=$(jq -r '.region.name // .region // empty' <<<"$j")
    user=$(jq -r '.user.display_name // .user.user_email // empty' <<<"$j")
    acct_name=$(jq -r '.account.name // empty' <<<"$j")
    acct_guid=$(jq -r '.account.guid // empty' <<<"$j")
    acct_id=$(jq -r '.account.bss // empty' <<<"$j")
    rg=$(jq -r '.resource_group.name // empty' <<<"$j")

    [[ -z "$api" ]] && api="unknown"
    [[ -z "$region" ]] && region="unknown"
    [[ -z "$user" ]] && user="unknown"
    [[ -z "$acct_name" ]] && acct_name="unknown"
    [[ -z "$acct_guid" ]] && acct_guid="unknown"
    [[ -z "$acct_id" ]] && acct_id="unknown"
    [[ -z "$rg" ]] && rg="none"

    printf "%sAPI endpoint:%s %s\n"   "${BOLD}${CYAN}" "${RESET}" "$api"
    printf "%sRegion:%s       %s\n"   "${BOLD}${CYAN}" "${RESET}" "$region"
    printf "%sUser:%s         %s\n"   "${BOLD}${CYAN}" "${RESET}" "$user"
    printf "%sAccount:%s      %s (%s) <-> %s\n" \
      "${BOLD}${CYAN}" "${RESET}" "$acct_name" "$(_mask "$acct_guid")" "$acct_id"
    printf "%sResource group:%s %s\n" "${BOLD}${CYAN}" "${RESET}" "$rg"
    return 0
  fi

  # fallback: parse human-readable
  local t; t="$(ibmcloud target 2>/dev/null || true)"
  [[ -z "$t" ]] && { printf "%sNot logged in.%s\n" "$YELLOW" "$RESET"; return 1; }

  local api region user account rg
  api="$(awk -F': *' '/^API endpoint:/ {print $2}' <<<"$t")"
  region="$(awk -F': *' '/^Region:/ {print $2}' <<<"$t")"
  user="$(awk -F': *' '/^User:/ {print $2}' <<<"$t")"
  account="$(awk -F': *' '/^Account:/ {print $2}' <<<"$t")"
  rg="$(awk -F': *' '/^Resource group:/ {print $2}' <<<"$t")"

  [[ -z "$api" ]] && api="unknown"
  [[ -z "$region" ]] && region="unknown"
  [[ -z "$user" ]] && user="unknown"
  [[ -z "$account" ]] && account="unknown"
  if [[ -z "$rg" || "$rg" =~ ^No\ resource ]]; then rg="none"; fi

  printf "%sAPI endpoint:%s %s\n"   "${BOLD}${CYAN}" "${RESET}" "$api"
  printf "%sRegion:%s       %s\n"   "${BOLD}${CYAN}" "${RESET}" "$region"
  printf "%sUser:%s         %s\n"   "${BOLD}${CYAN}" "${RESET}" "$user"
  printf "%sAccount:%s      %s\n"   "${BOLD}${CYAN}" "${RESET}" "$account"
  printf "%sResource group:%s %s\n" "${BOLD}${CYAN}" "${RESET}" "$rg"
}

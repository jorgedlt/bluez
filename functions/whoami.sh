#!/usr/bin/env bash
# functions/whoami.sh — ibmwhoami: show IBM Cloud login/account info

# Usage: ibmwhoami
ibmwhoami() {
  local txt json have_jq=0

  if ! txt="$(ibmcloud target 2>/dev/null)"; then
    echo "Not logged in. Run ibmlogin." >&2
    return 1
  fi

  if command -v jq >/dev/null 2>&1; then
    have_jq=1
    json="$(ibmcloud target --output json 2>/dev/null || true)"
    # Some CLI builds can emit nothing or partial JSON on first login
    [[ -n "$json" ]] || have_jq=0
  fi

  if (( have_jq )); then
    printf '%s\n' "$json" | jq -r '
      . as $t |
      "API endpoint: " + ($t.api_endpoint // "unknown") + "\n" +
      "Region:       " +
        (if $t.region == null then "unknown"
         elif ($t.region|type)=="string" then $t.region
         else ($t.region.name // $t.region.id // "unknown") end) + "\n" +
      "User:         " +
        (if $t.user == null then "unknown"
         elif ($t.user|type)=="string" then $t.user
         else ($t.user.email // $t.user.user // "unknown") end) + "\n" +
      "Account:      " +
        (( $t.account.name // "unknown") + " (" + ( $t.account.guid // "unknown") + ") <-> " +
         ( $t.account.bluemix_subscriptions[0].ims_account_id // "unknown")) + "\n" +
      "Resource group: " +
        (if $t.resource_group == null then "none"
         elif ($t.resource_group|type)=="string" then $t.resource_group
         else ($t.resource_group.name // "none") end)
    '
    return 0
  fi

  # Fallback: parse human-readable output
  # Preserve full URL including "https://"
  local api region user account rg
  api="$(sed -nE 's/^API endpoint:[[:space:]]*(.+)$/\1/p' <<<"$txt")"
  region="$(sed -nE 's/^Region:[[:space:]]*(.+)$/\1/p' <<<"$txt")"
  user="$(sed -nE 's/^User:[[:space:]]*(.+)$/\1/p' <<<"$txt")"
  account="$(sed -nE 's/^Account:[[:space:]]*(.+)$/\1/p' <<<"$txt")"
  rg="$(sed -nE 's/^Resource group:[[:space:]]*(.+)$/\1/p' <<<"$txt")"

  [[ -n "$api"    ]] || api="unknown"
  [[ -n "$region" ]] || region="unknown"
  [[ -n "$user"   ]] || user="unknown"
  [[ -n "$account" ]] || account="unknown"
  if [[ -z "$rg" || "$rg" =~ ^No[[:space:]]resource[[:space:]]group[[:space:]]targeted ]]; then
    rg="none"
  fi

  echo "API endpoint: $api"
  echo "Region:       $region"
  echo "User:         $user"
  echo "Account:      $account"
  echo "Resource group: $rg"
}

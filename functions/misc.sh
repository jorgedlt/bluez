#!/usr/bin/env bash
# misc.sh — plugins, env cleanups, quick targets, interactive account picker
# Note: we intentionally DO NOT add an ibmswitch() here to avoid conflicting
# with the newer ibmswitchaccount in login.sh.

#+ Show installed IBM Cloud CLI plugins
# Usage: ibmplugins
ibmplugins() { ibmcloud plugin list; }

# Clear IBM Cloud related environment variables
# Usage: ibmclr [pattern]
ibmclr() {
  local pat="${1:-IBMCLOUD|KP_INSTANCE_ID|COS_}"
  local vars; vars="$(env | awk -F= '{print $1}' | grep -E "$pat")"
  [[ -n "$vars" ]] || { echo "No matching vars for pattern: $pat"; return 0; }
  for v in $vars; do
    echo "unset $v"
    unset "$v"
  done
}

# Quick target shortcuts
qsu() { ibmcloud target -r us-south -g default && ibmwhoami; }
qsee(){ ibmcloud target -r eu-de    -g default && ibmwhoami; }

#+ Interactive account selector
# Usage: ibmpick
ibmpick() {
  mapfile -t ACC_LINES < <(ibmcloud account list --output json | jq -r '.[] | "\(.name)\t\(.account_id)"' | sort)
  PS3="Select IBM Cloud account: "
  select line in "${ACC_LINES[@]}" "exit"; do
    [[ "$line" == "exit" || -z "$line" ]] && break
    acct_id="$(echo "$line" | awk -F'\t' '{print $2}')"
    ibmcloud account switch -a "$acct_id" && ibmwhoami
    break
  done
}

# Optional convenience: wrapper to set region and RG, then show status
#+ Set region and resource group, then show status
# Usage: ibmtarget <region> [resource_group]
ibmtarget() {
  [[ $# -ge 1 ]] || { echo "Usage: ibmtarget <region> [resource_group]"; return 2; }
  local region="$1"; local rg="${2:-}"
  if [[ -n "$rg" ]]; then
    ibmcloud target -r "$region" -g "$rg"
  else
    ibmcloud target -r "$region"
  fi
  ibmwhoami
}

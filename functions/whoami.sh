#!/usr/bin/env bash
# functions/whoami.sh — ibmwhoami: show IBM Cloud login/account info

ibmwhoami() {
  # If not logged in, ibmcloud target returns nonzero and prints error
  local out rc jq_ok=0 endpoint rg_name
  if ! out="$(ibmcloud target 2>&1)"; then
    echo "Not logged in. Run ibmlogin." >&2
    return 1
  fi
  # Try to parse with jq if available, else fallback to text parsing
  if command -v jq >/dev/null 2>&1; then
    jq_ok=1
  fi
  if (( jq_ok )) && out_json="$(ibmcloud target --output json 2>/dev/null)"; then
    endpoint="$(echo "$out_json" | jq -r '.Region.Endpoint // .ApiEndpoint // empty')"
    rg_name="$(echo "$out_json" | jq -r '.ResourceGroup.Name // "none"')"
  else
    endpoint="$(echo "$out" | grep -E '^API endpoint:' | sed 's/API endpoint:[[:space:]]*//')"
    rg_name="$(echo "$out" | grep -E '^Resource group:' | sed 's/Resource group:[[:space:]]*//')"
    [[ -z "$endpoint" ]] && endpoint="none"
    [[ -z "$rg_name" ]] && rg_name="none"
  fi
  echo "Endpoint: $endpoint"
  echo "Resource Group: $rg_name"
  return 0
}

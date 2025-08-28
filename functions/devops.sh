# functions/devops.sh
#!/usr/bin/env bash
# devops.sh — DevOps toolchains (list/show/create), renamed functions
# Requires IBM Cloud CLI "dev" commands (built into CLI).

__tc_ensure_target() {
  _ensure_region "$IBMC_REGION"
  _ensure_rg
}

# List toolchains (pretty table)
ibmtoolchainsls() {
  __tc_ensure_target

  local j
  j="$(ibmcloud dev toolchains --output json 2>/dev/null || true)"
  if [[ -z "$j" || "$j" == "null" ]]; then
    echo "No toolchains returned (empty)."
    return 0
  fi

  local header="Name\tGUID\tRegion\tResourceGroupID\tCreated"
  local widths="40,38,16,36,24"

  printf "%s" "$j" \
    | jq -r '.items[]? | [
        (.name // "-"),
        (.toolchain_guid // "-"),
        (.region_id // "-"),
        (.container.guid // "-"),
        (.created // "-")
      ] | @tsv' \
    | _print_table "$header" "$widths"
}

# Show one toolchain by name or GUID
ibmtoolchainshow() {
  local sel="${1:-}"
  [[ -n "$sel" ]] || { echo "Usage: ibmtoolchainshow <name-or-guid>"; return 1; }

  __tc_ensure_target

  local j
  j="$(ibmcloud dev toolchains --output json 2>/dev/null || true)"
  [[ -n "$j" && "$j" != "null" ]] || { echo "Failed to fetch toolchains"; return 1; }

  printf "%s" "$j" \
    | jq -r --arg s "$sel" '
        .items[]? | select(.name==$s or .toolchain_guid==$s) |
        "Name: \(.name)\nGUID: \(.toolchain_guid)\nRegion: \(.region_id)\nResource Group: \(.container.guid)\nCreated: \(.created)\nUpdated: \(.updated_at)\nTemplate: \(.template.name // "-")"
      '
}

# Create a toolchain via DevOps API (best-effort)
# Usage: ibmtoolchainmk <name> [-g ResourceGroupName] [-r region-id]
ibmtoolchainmk() {
  local name="${1:-}"; shift || true
  [[ -n "$name" ]] || { echo "Usage: ibmtoolchainmk <name> [-g ResourceGroupName] [-r region]"; return 1; }

  local rg_name="$IBMC_RG" region="$IBMC_REGION"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -g|--group)   rg_name="$2"; shift 2 ;;
      -r|--region)  region="$2"; shift 2 ;;
      *) echo "Unknown arg: $1"; return 1 ;;
    esac
  done

  _ensure_region "$region"
  ibmcloud target -g "$rg_name" >/dev/null 2>&1 || true

  local rg_id
  rg_id="$(ibmcloud resource groups --output json 2>/dev/null | jq -r --arg n "$rg_name" '.[] | select(.name==$n) | .id' | awk 'NF')"
  [[ -n "$rg_id" ]] || { echo "Failed to resolve resource group id for '$rg_name'"; return 1; }

  local token
  token="$(ibmcloud iam oauth-tokens 2>/dev/null | awk -F': ' '/IAM token/ {print $2}')"
  [[ -n "$token" ]] || { echo "Failed to obtain IAM token. Are you logged in?"; return 1; }

  local host="devops-api.${region}.devops.cloud.ibm.com"
  local url="https://${host}/v1/toolchains"

  local body
  body="$(jq -n --arg nm "$name" --arg rg "$rg_id" '{name:$nm, resource_group_id:$rg}')" || return 1

  local resp http
  resp="$(curl -sS -X POST "$url" \
    -H "Authorization: $token" \
    -H "Content-Type: application/json" \
    -d "$body" -w "\n%{http_code}")" || return 1

  http="$(printf "%s" "$resp" | tail -n1)"
  resp="$(printf "%s" "$resp" | sed '$d')"

  if [[ "$http" != "201" && "$http" != "200" ]]; then
    echo "Create failed (HTTP $http):"
    printf "%s\n" "$resp"
    return 1
  fi

  printf "%s" "$resp" \
    | jq -r '"Created toolchain:\nName: \(.name)\nGUID: \(.toolchain_guid)\nRegion: \(.region_id)\nResource Group: \(.container.guid)\nCreated: \(.created)"'
}

#!/usr/bin/env bash
# devops.sh, DevOps toolchains helpers

# Fallbacks if init.sh was not sourced
if ! declare -F _need >/dev/null 2>&1; then
  _need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; return 1; }; }
fi
if ! declare -F _print_table >/dev/null 2>&1; then
  _print_table() {
    # header and widths are required
    local header="$1" widths="$2"
    local IFS=$'\t' ; read -r -a cols <<<"$header"
    IFS=','         ; read -r -a w    <<<"$widths"
    for i in "${!cols[@]}"; do
      printf "%-*s%s" "${w[i]}" "${cols[i]}" $([[ $i -lt $((${#cols[@]}-1)) ]] && printf "  ")
    done
    printf "\n"
    while IFS=$'\t' read -r -a r; do
      for i in "${!r[@]}"; do
        printf "%-*s%s" "${w[i]}" "${r[i]}" $([[ $i -lt $((${#r[@]}-1)) ]] && printf "  ")
      done
      printf "\n"
    done
  }
fi
if ! declare -F _ensure_region >/dev/null 2>&1; then
  _ensure_region() { [[ -n "${1:-}" ]] && ibmcloud target -r "$1" >/dev/null 2>&1 || true; }
fi
if ! declare -F _ensure_rg >/dev/null 2>&1; then
  _ensure_rg() { [[ -n "${1:-}" ]] && ibmcloud target -g "$1" >/dev/null 2>&1 || true; }
fi

__tc_ensure_target() {
  _ensure_region "${IBMC_REGION:-}"
  _ensure_rg     "${IBMC_RG:-}"
}

# Usage: ibmtoolchainsls
ibmtoolchainsls() {
  _need ibmcloud || return 1
  _need jq || return 1
  __tc_ensure_target

  local j
  j="$(ibmcloud dev toolchains --output json 2>/dev/null || true)"
  if [[ -z "$j" || "$j" == "null" ]]; then
    echo "No toolchains returned."
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

# Usage: ibmtoolchainshow <name-or-guid>
ibmtoolchainshow() {
  _need ibmcloud || return 1
  _need jq || return 1
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

# Usage: ibmtoolchainmk <name> [-g ResourceGroupName] [-r region]
ibmtoolchainmk() {
  _need ibmcloud || return 1
  _need jq || return 1

  local name="${1:-}"; shift || true
  [[ -n "$name" ]] || { echo "Usage: ibmtoolchainmk <name> [-g ResourceGroupName] [-r region]"; return 1; }

  local rg_name="${IBMC_RG:-default}" region="${IBMC_REGION:-us-south}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -g|--group)   rg_name="$2"; shift 2 ;;
      -r|--region)  region="$2";  shift 2 ;;
      *) echo "Unknown arg: $1"; return 1 ;;
    esac
  done

  _ensure_region "$region"
  ibmcloud target -g "$rg_name" >/dev/null 2>&1 || true

  local rg_id
  rg_id="$(ibmcloud resource groups --output json 2>/dev/null | jq -r --arg n "$rg_name" '.[] | select(.name==$n) | .id' | awk 'NF')"
  [[ -n "$rg_id" ]] || { echo "Failed to resolve resource group id for '$rg_name'"; return 1; }

  local token
  token="$(ibmcloud iam oauth-tokens --output json 2>/dev/null | jq -r '.iam_token // empty')"
  if [[ -z "$token" ]]; then
    token="$(ibmcloud iam oauth-tokens 2>/dev/null | awk -F': ' '/IAM token/ {print $2}')"
  fi
  [[ -n "$token" ]] || { echo "Failed to obtain IAM token. Are you logged in?"; return 1; }

  local host="devops-api.${region}.devops.cloud.ibm.com"
  local url="https://${host}/v1/toolchains"

  local body
  body="$(jq -n --arg nm "$name" --arg rg "$rg_id" '{name:$nm, resource_group_id:$rg}')" || return 1

  # Use curl with explicit status capture
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

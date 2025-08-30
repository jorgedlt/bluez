#!/usr/bin/env bash
# cos.sh, Cloud Object Storage helpers

if ! declare -F _need >/dev/null 2>&1; then
  _need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; return 1; }; }
fi

_cos_region_default() {
  if [[ -n "${IBMC_REGION:-}" ]]; then
    printf '%s' "$IBMC_REGION"
  else
    ibmcloud target 2>/dev/null | awk -F': *' '/^Region:/ {print $2}'
  fi
}

# Usage: ibmcosls [regex]
ibmcosls() {
  _need ibmcloud || return 1
  _need jq || return 1
  local filt="${1:-}"
  local j
  j="$(ibmcloud cos bucket-list --output json 2>/dev/null || true)"

  if [[ -z "$j" || "$j" == "null" ]] || ! jq -e . >/dev/null 2>&1 <<<"$j"; then
    echo "No buckets, or COS not configured. Try: ibmcloud cos config" >&2
    return 0
  fi

  printf "%-48s %s\n" "Bucket" "Region"
  printf "%-48s %s\n" "------" "------"
  jq -r '.Buckets[]?.Name' <<<"$j" | while read -r b; do
    [[ -n "$filt" && ! "$b" =~ $filt ]] && continue
    local region=""
    region="$(ibmcloud cos bucket-location-get --bucket "$b" --output json 2>/dev/null \
             | jq -r '.LocationConstraint // empty' 2>/dev/null)"
    printf "%-48s %s\n" "$b" "${region:-"-"}"
  done
}

# Usage: ibmcosshow <bucket>
ibmcosshow() {
  _need ibmcloud || return 1
  _need jq || return 1
  [[ $# -eq 1 ]] || { echo "Usage: ibmcosshow <bucket>"; return 2; }
  local b="$1"
  local region object_count
  region="$(ibmcloud cos bucket-location-get --bucket "$b" --output json 2>/dev/null \
           | jq -r '.LocationConstraint // empty' 2>/dev/null)"
  object_count="$(ibmcloud cos object-list --bucket "$b" --output json 2>/dev/null \
                | jq -r '(.Contents|length) // 0' 2>/dev/null)"
  echo "Bucket : $b"
  echo "Region : ${region:-"-"}"
  echo "Objects: ${object_count:-0} (first page)"
}

# Usage: ibmcosmk <bucket> [-r region] [-c class]
ibmcosmk() {
  _need ibmcloud || return 1
  _need jq || return 1
  local bucket="" region="" class=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r|--region) region="$2"; shift 2 ;;
      -c|--class)  class="$2"; shift 2 ;;
      *) if [[ -z "$bucket" ]]; then bucket="$1"; shift; else echo "Unexpected arg: $1" >&2; return 2; fi ;;
    esac
  done
  [[ -n "$bucket" ]] || { echo "Usage: ibmcosmk <bucket> [-r region] [-c class]"; return 2; }
  [[ -n "$region" ]] || region="$(_cos_region_default)"
  [[ -n "$region" ]] || { echo "Region is required (set IBMC_REGION or pass -r)"; return 2; }

  local args=( bucket-create --bucket "$bucket" --region "$region" )
  [[ -n "$class" ]] && args+=( --class "$class" )

  echo "Creating bucket '$bucket' in region '$region'${class:+ (class: $class)}..."
  ibmcloud cos "${args[@]}"
}

# Usage: ibmcosrm <bucket>
ibmcosrm() {
  _need ibmcloud || return 1
  [[ $# -eq 1 ]] || { echo "Usage: ibmcosrm <bucket>"; return 2; }
  local b="$1"
  echo "Deleting bucket '$b' (bucket must be empty)..."
  if ! ibmcloud cos bucket-delete --bucket "$b"; then
    echo "Delete failed. Ensure the bucket is empty (ibmcosobjls $b) before deleting." >&2
    return 1
  fi
}

# Usage: ibmcosobjls <bucket> [prefix]
ibmcosobjls() {
  _need ibmcloud || return 1
  _need jq || return 1
  [[ $# -ge 1 ]] || { echo "Usage: ibmcosobjls <bucket> [prefix]"; return 2; }
  local b="$1"; local p="${2:-}"
  local j
  if [[ -n "$p" ]]; then
    j="$(ibmcloud cos object-list --bucket "$b" --prefix "$p" --output json 2>/dev/null || true)"
  else
    j="$(ibmcloud cos object-list --bucket "$b" --output json 2>/dev/null || true)"
  fi
  printf "%-60s %12s %s\n" "Key" "Size" "LastModified"
  printf "%-60s %12s %s\n" "---" "----" "------------"
  printf '%s' "$j" \
    | jq -r '.Contents[]? | [.Key, (.Size|tostring), .LastModified] | @tsv' \
    | awk -F'\t' '{printf "%-60s %12s %s\n",$1,$2,$3}'
}

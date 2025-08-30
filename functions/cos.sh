#!/usr/bin/env bash
# cos.sh — Cloud Object Storage helpers
# Requires: IBM Cloud CLI (`ibmcloud`) with the COS plugin configured
#           via `ibmcloud cos config`. Also requires `jq`.
#
# Commands:
#   ibmcosls [regex]                          # List buckets (optionally filtered)
#   ibmcosshow <bucket>                       # Show details for a bucket
#   ibmcosmk <bucket> [-r region] [-c class]  # Create a bucket (region required)
#   ibmcosrm <bucket>                         # Delete an (empty) bucket
#   ibmcosobjls <bucket> [prefix]             # List objects within a bucket
#
# Notes:
# - Bucket deletes will fail if the bucket is not empty (we do not auto-purge).
# - Object listings may page at 1000 keys; the CLI returns a partial view by default.

# ---------- tiny helpers ----------
_cos_need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; return 1; }; }
_cos_region_default() {
  # Prefer explicitly set IBMC_REGION; otherwise ask the CLI target.
  if [[ -n "${IBMC_REGION:-}" ]]; then
    printf '%s' "$IBMC_REGION"
  else
    ibmcloud target 2>/dev/null | awk -F': *' '/^Region:/ {print $2}'
  fi
}

# ---------- list buckets ----------
# Usage: ibmcosls [regex]
ibmcosls() {
  _cos_need ibmcloud || return 1
  _cos_need jq || return 1

  local filt="${1:-}"
  local j
  j="$(ibmcloud cos bucket-list --output json 2>/dev/null || true)"

  if [[ -z "$j" || "$j" == "null" ]]; then
    echo "No buckets (or COS not configured). Try: ibmcloud cos config" >&2
    return 0
  fi

  # Print as a simple table, optional regex filter on name
  printf "%-48s %s\n" "Bucket" "Region"
  printf "%-48s %s\n" "------" "------"
  jq -r '.Buckets[]?.Name' <<<"$j" | while read -r b; do
    [[ -n "$filt" && ! "$b" =~ $filt ]] && continue
    # Try to resolve region (best-effort; command name may vary across plugin versions)
    local region=""
    region="$(ibmcloud cos bucket-location-get --bucket "$b" --output json 2>/dev/null \
             | jq -r '.LocationConstraint // empty' 2>/dev/null)"
    printf "%-48s %s\n" "$b" "${region:-"-"}"
  done
}

# ---------- show one bucket ----------
# Usage: ibmcosshow <bucket>
ibmcosshow() {
  _cos_need ibmcloud || return 1
  _cos_need jq || return 1
  [[ $# -eq 1 ]] || { echo "Usage: ibmcosshow <bucket>"; return 2; }

  local b="$1"
  local region object_count

  region="$(ibmcloud cos bucket-location-get --bucket "$b" --output json 2>/dev/null \
           | jq -r '.LocationConstraint // empty' 2>/dev/null)"
  # Get up to first 1000 objects to provide a quick count
  object_count="$(ibmcloud cos object-list --bucket "$b" --output json 2>/dev/null \
                | jq -r '(.Contents|length) // 0' 2>/dev/null)"

  echo "Bucket : $b"
  echo "Region : ${region:-"-"}"
  echo "Objects: ${object_count:-0} (first page)"
}

# ---------- create bucket ----------
# Usage: ibmcosmk <bucket> [-r region] [-c class]
# Example: ibmcosmk my-bucket -r us-south -c standard
ibmcosmk() {
  _cos_need ibmcloud || return 1
  _cos_need jq || return 1

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

# ---------- delete bucket ----------
# Usage: ibmcosrm <bucket>
# (Fails if bucket not empty; we do not recursively purge for safety.)
ibmcosrm() {
  _cos_need ibmcloud || return 1
  [[ $# -eq 1 ]] || { echo "Usage: ibmcosrm <bucket>"; return 2; }
  local b="$1"

  echo "Deleting bucket '$b' (bucket must be empty)..."
  if ! ibmcloud cos bucket-delete --bucket "$b"; then
    echo "Delete failed. Ensure the bucket is empty (ibmcosobjls $b) before deleting." >&2
    return 1
  fi
}

# ---------- list objects in a bucket ----------
# Usage: ibmcosobjls <bucket> [prefix]
# Example: ibmcosobjls my-bucket logs/2025/
ibmcosobjls() {
  _cos_need ibmcloud || return 1
  _cos_need jq || return 1
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

# ------------- END -------------

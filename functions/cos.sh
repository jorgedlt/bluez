#!/usr/bin/env bash
# cos.sh — Cloud Object Storage helpers
# Requires 'ibmcloud cos config' done beforehand.

# List COS buckets
ibmcosbuckets() {
  ibmcloud cos bucket-list --output json | jq -r '.Buckets[] | .Name' 2>/dev/null \
    | awk '{printf "  - %s\n",$0}'
}

# List objects in a bucket, optional prefix
# Usage: ibmcosls <bucket> [prefix]
ibmcosls() {
  [[ $# -ge 1 ]] || { echo "Usage: ibmcosls <bucket> [prefix]"; return 2; }
  local b="$1"; local p="${2:-}"
  if [[ -n "$p" ]]; then
    ibmcloud cos object-list --bucket "$b" --prefix "$p" --output json \
      | jq -r '.Contents[]? | [.Key, .Size, .LastModified] | @tsv' \
      | awk -F'\t' 'BEGIN{
          printf "%-60s %12s %s\n","Key","Size","LastModified"
        }{
          printf "%-60s %12s %s\n",$1,$2,$3
        }'
  else
    ibmcloud cos object-list --bucket "$b" --output json \
      | jq -r '.Contents[]? | [.Key, .Size, .LastModified] | @tsv' \
      | awk -F'\t' 'BEGIN{
          printf "%-60s %12s %s\n","Key","Size","LastModified"
        }{
          printf "%-60s %12s %s\n",$1,$2,$3
        }'
  fi
}

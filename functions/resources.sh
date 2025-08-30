#!/usr/bin/env bash
# resources.sh, resource inventory and regions

# Fallbacks if init.sh was not sourced
if ! declare -F _need >/dev/null 2>&1; then
  _need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; return 1; }; }
fi

# Usage: ibmresls [regex]
ibmresls() {
  _need ibmcloud || return 1
  _need jq || return 1
  local srch="${1:-.}"
  ibmcloud resource service-instances --all-resource-groups --output json \
    | jq -r '.[] | [.name, .resource_group_name, .region_id, .service_name, .state] | @tsv' \
    | awk -F'\t' -v s="$srch" 'BEGIN{
        printf "%-40s %-22s %-12s %-28s %-8s\n","Name","ResourceGroup","Region","Service","State"
      }{
        if ($0~s) printf "%-40s %-22s %-12s %-28s %-8s\n",$1,$2,$3,$4,$5
      }'
}

# Usage: ibmresdump <service_instance_name>
ibmresdump() {
  _need ibmcloud || return 1
  _need jq || return 1
  [[ $# -eq 1 ]] || { echo "Usage: ibmresdump <service_instance_name>"; return 2; }
  ibmcloud resource service-instance "$1" --output json | jq .
}

# Usage: ibmresrm <service_instance_name>
ibmresrm() {
  _need ibmcloud || return 1
  [[ $# -eq 1 ]] || { echo "Usage: ibmresrm <service_instance_name>"; return 2; }
  local name="$1"
  read -r -p "Delete service instance '${name}' in current RG? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted"; return 1; }
  ibmcloud resource service-instance-delete "$name" --recursive --force
}

# Usage: ibmregionsls
ibmregionsls() {
  _need ibmcloud || return 1
  _need jq || return 1
  echo "VPC regions"
  ibmcloud is regions --output json | jq -r '.[] | [.name, .endpoint] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-16s %s\n","Region","Endpoint"}{printf "%-16s %s\n",$1,$2}'
  echo
  echo "Account regions"
  ibmcloud regions
}

# Usage: ibmregionssum
ibmregionssum() {
  _need ibmcloud || return 1
  _need jq || return 1
  ibmcloud resource search 'type:*' --output json \
    | jq -r '.items[] | .region_id // "global"' \
    | sort | uniq -c | sort -nr
}

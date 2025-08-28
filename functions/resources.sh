#!/usr/bin/env bash
# resources.sh — resource inventory, group detail, regions

# Show a single resource group by name
# Usage: ibmrgshow <resource_group_name>
ibmrgshow() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmrgshow <resource_group_name>"; return 2; }
  ibmcloud resource group "$1" --output json | jq .
}

# List service instances across all resource groups
# Optional grep-like filter: ibmresls <regex>
ibmresls() {
  local srch="${1:-.}"
  ibmcloud resource service-instances --all-resource-groups --output json \
    | jq -r '.[] | [.name, .resource_group_name, .region_id, .service_name, .state] | @tsv' \
    | awk -F'\t' -v s="$srch" 'BEGIN{
        printf "%-40s %-22s %-12s %-28s %-8s\n","Name","ResourceGroup","Region","Service","State"
      }{
        if ($0~s) printf "%-40s %-22s %-12s %-28s %-8s\n",$1,$2,$3,$4,$5
      }'
}

# Dump a single service instance JSON by name
# Usage: ibmresdump <service_instance_name>
ibmresdump() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmresdump <service_instance_name>"; return 2; }
  ibmcloud resource service-instance "$1" --output json | jq .
}

# Delete a service instance by name, with a confirmation prompt
# Usage: ibmresrm <service_instance_name>
ibmresrm() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmresrm <service_instance_name>"; return 2; }
  local name="$1"
  read -r -p "Delete service instance '${name}' in current RG? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted"; return 1; }
  ibmcloud resource service-instance-delete "$name" --recursive --force
}

# Regions overview
ibmregionsls() {
  echo "VPC regions"
  ibmcloud is regions --output json | jq -r '.[] | [.name, .endpoint] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-16s %s\n","Region","Endpoint"}{printf "%-16s %s\n",$1,$2}'
  echo
  echo "Account regions (general)"
  ibmcloud regions
}

# Count resources by region (using resource search)
ibmregionssum() {
  ibmcloud resource search 'type:*' --output json \
    | jq -r '.items[] | .region_id // "global"' \
    | sort | uniq -c | sort -nr
}

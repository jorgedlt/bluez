#!/usr/bin/env bash
# Jorge de la Torre | Cloud DevOps & IOT | jorge.delatorre@dematic.com | o:770.325.9284 | c:312.612.9113
# ibmfuncs.sh — IBM Cloud CLI helpers analogous to your Azure set

# Save as ~/.ibmfuncs.sh then: source ~/.ibmfuncs.sh

# Minimal ANSI colors
RESET=$'\033[0m'; BOLD=$'\033[1m'
RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'
BLUE=$'\033[34m'; MAGENTA=$'\033[35m'; CYAN=$'\033[36m'; GRAY=$'\033[90m'

# Path of this file for help indexing
export IBMFUNC_FILE="${IBMFUNC_FILE:-$HOME/.ibmfuncs.sh}"

# ---------------------------------------------------------------------------
#. ibmhelp        -- List or search helper functions in this file
ibmhelp () {
  local f="${IBMFUNC_FILE}"
  [[ -r "$f" ]] || { echo "File not found: $f"; return 1; }
  if [[ $# -eq 0 ]]; then
    grep -n '^#\.' "$f" | sed 's/^#\.//'
  else
    local topic="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    grep -n '^#\.' "$f" | grep -i -- "$topic" | sed 's/^#\.//'
  fi
}

# ---------------------------------------------------------------------------
# Internals, current target info
# ---------------------------------------------------------------------------

# _ibm_target_json caches ibmcloud target --output json
_ibm_target_json () {
  ibmcloud target --output json 2>/dev/null
}

# _ibmgetAccountID     -- current Account ID
_ibmgetAccountID () { _ibm_target_json | jq -r '.account.id'; }

# _ibmgetAccountName   -- current Account Name
_ibmgetAccountName () { _ibm_target_json | jq -r '.account.name'; }

# _ibmgetRegion        -- current Region
_ibmgetRegion () { _ibm_target_json | jq -r '.region.name // .region'; }

# _ibmgetResourceGroup -- current Resource Group
_ibmgetResourceGroup () { _ibm_target_json | jq -r '.resource_group.name // .resource_group'; }

# _ibmgetUser          -- current user (email or name)
_ibmgetUser () { _ibm_target_json | jq -r '.user.email // .user.name // "unknown"'; }

# Simple banner
_ibm_banner () {
  echo "${BOLD}${CYAN}${1}${RESET}"
}

# ---------------------------------------------------------------------------
#. ibmwhoami     -- Show logged in user, account, region and resource group
ibmwhoami () {
  local acctN="$(_ibmgetAccountName)"
  local acctI="$(_ibmgetAccountID)"
  local region="$(_ibmgetRegion)"
  local rgrp="$(_ibmgetResourceGroup)"
  local user="$(_ibmgetUser)"
  _ibm_banner "Current IBM Cloud target"
  printf "  Account     : %s\n" "${acctN} (${acctI})"
  printf "  Region      : %s\n" "${region}"
  printf "  ResourceGrp : %s\n" "${rgrp}"
  printf "  User        : %s\n" "${user}"
}

# ---------------------------------------------------------------------------
# Accounts and targeting
# ---------------------------------------------------------------------------

#. ibmaccls     -- List accounts available to you
ibmaccls () {
  ibmcloud account list --output json | jq -r '.[] | [.name, .account_id, (.state // "unknown"), (.owner_ibmid // "n/a")] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-40s %-36s %-10s %s\n","Name","AccountID","State","Owner"}{printf "%-40s %-36s %-10s %s\n",$1,$2,$3,$4}'
}

#. ibmswitch    -- Switch account by Account ID
ibmswitch () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmswitch <ACCOUNT_ID>"; return 2; }
  ibmcloud account switch -a "$1"
  ibmwhoami
}

#. ibmpick      -- Interactive account selector
ibmpick () {
  mapfile -t ACC_LINES < <(ibmcloud account list --output json | jq -r '.[] | "\(.name)\t\(.account_id)"' | sort)
  PS3="Select IBM Cloud account: "
  select line in "${ACC_LINES[@]}" "exit"; do
    [[ "$line" == "exit" || -z "$line" ]] && break
    acct_id="$(echo "$line" | awk -F'\t' '{print $2}')"
    ibmcloud account switch -a "$acct_id" && ibmwhoami
    break
  done
}

#. ibmtarget    -- Set region and resource group, example: ibmtarget us-south default
ibmtarget () {
  [[ $# -ge 1 ]] || { echo "Usage: ibmtarget <region> [resource_group]"; return 2; }
  local region="$1"; local rg="$2"
  if [[ -n "$rg" ]]; then
    ibmcloud target -r "$region" -g "$rg"
  else
    ibmcloud target -r "$region"
  fi
  ibmwhoami
}

# ---------------------------------------------------------------------------
# Resource groups and resources
# ---------------------------------------------------------------------------

#. ibmrgls      -- List resource groups, optional grep filter
ibmrgls () {
  local srch="${1:-.}"
  ibmcloud resource groups --output json \
    | jq -r '.[] | [.name, .id, .state, (.quota_id // "n/a")] | @tsv' \
    | awk -F'\t' -v s="$srch" 'BEGIN{printf "%-30s %-36s %-8s %s\n","Name","ID","State","Quota"}{if ($0~s) printf "%-30s %-36s %-8s %s\n",$1,$2,$3,$4}'
}

#. ibmrgshow    -- Show a single resource group by name
ibmrgshow () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmrgshow <resource_group_name>"; return 2; }
  ibmcloud resource group "$1" --output json | jq .
}

#. ibmresls     -- List service instances across groups, optional grep filter
ibmresls () {
  local srch="${1:-.}"
  ibmcloud resource service-instances --all-resource-groups --output json \
    | jq -r '.[] | [.name, .resource_group_name, .region_id, .service_name, .state] | @tsv' \
    | awk -F'\t' -v s="$srch" 'BEGIN{printf "%-40s %-22s %-12s %-28s %-8s\n","Name","ResourceGroup","Region","Service","State"}{if ($0~s) printf "%-40s %-22s %-12s %-28s %-8s\n",$1,$2,$3,$4,$5}'
}

#. ibmresdump   -- Dump a service instance JSON by name
ibmresdump () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmresdump <service_instance_name>"; return 2; }
  ibmcloud resource service-instance "$1" --output json | jq .
}

#. ibmresrm     -- Delete a service instance by name with confirmation
ibmresrm () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmresrm <service_instance_name>"; return 2; }
  local name="$1"
  read -r -p "Delete service instance '${name}' in $( _ibmgetResourceGroup )? [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]] || { echo "Aborted"; return 1; }
  ibmcloud resource service-instance-delete "$name" --recursive --force
}

#. ibmregionsls -- List regions (VPC and classic)
ibmregionsls () {
  echo "${CYAN}VPC regions${RESET}"
  ibmcloud is regions --output json | jq -r '.[] | [.name, .endpoint] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-16s %s\n","Region","Endpoint"}{printf "%-16s %s\n",$1,$2}'
  echo
  echo "${CYAN}Account regions (general)${RESET}"
  ibmcloud regions
}

#. ibmregionssum -- Count resources by region using resource search
ibmregionssum () {
  ibmcloud resource search 'type:*' --output json \
    | jq -r '.items[] | .region_id // "global"' \
    | sort | uniq -c | sort -nr
}

# ---------------------------------------------------------------------------
# Tags
# ---------------------------------------------------------------------------

#. ibmtagls     -- List tags on a named resource
ibmtagls () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmtagls <resource_name>"; return 2; }
  ibmcloud resource tags --resource-name "$1" --output json | jq .
}

#. ibmtagadd    -- Attach tag(s) to a named resource, comma separated list
ibmtagadd () {
  [[ $# -ge 2 ]] || { echo "Usage: ibmtagadd <resource_name> <tag1,tag2,...> [user|access]"; return 2; }
  local name="$1"; local tags="$2"; local ttype="${3:-user}"
  ibmcloud resource tag-attach --resource-name "$name" --tag-names "$tags" --tag-type "$ttype"
}

#. ibmtagrm     -- Detach tag(s) from a named resource
ibmtagrm () {
  [[ $# -ge 2 ]] || { echo "Usage: ibmtagrm <resource_name> <tag1,tag2,...> [user|access]"; return 2; }
  local name="$1"; local tags="$2"; local ttype="${3:-user}"
  ibmcloud resource tag-detach --resource-name "$name" --tag-names "$tags" --tag-type "$ttype"
}

# ---------------------------------------------------------------------------
# VPC virtual servers, networking, IPs and security groups
# ---------------------------------------------------------------------------

#. ibmvmls      -- List VPC instances
ibmvmls () {
  ibmcloud is instances --output json \
    | jq -r '.[] | [.name, .id, .zone.name, .status, (.primary_network_interface.primary_ipv4_address // "n/a")] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-32s %-36s %-12s %-10s %s\n","Name","ID","Zone","Status","PrimaryIPv4"}{printf "%-32s %-36s %-12s %-10s %s\n",$1,$2,$3,$4,$5}'
}

#. ibmvmshow    -- Show VPC instance details
ibmvmshow () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmvmshow <instance_id_or_name>"; return 2; }
  ibmcloud is instance "$1" --output json | jq .
}

#. ibmvmstart   -- Start a VPC instance
ibmvmstart () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmvmstart <instance_id_or_name>"; return 2; }
  ibmcloud is instance-start "$1"
}

#. ibmvmstop    -- Stop a VPC instance
ibmvmstop () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmvmstop <instance_id_or_name>"; return 2; }
  ibmcloud is instance-stop "$1"
}

#. ibmvmreboot  -- Reboot a VPC instance
ibmvmreboot () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmvmreboot <instance_id_or_name>"; return 2; }
  ibmcloud is instance-reboot "$1"
}

#. ibmvmip      -- Show primary IPv4 and attached floating IPs
ibmvmip () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmvmip <instance_id_or_name>"; return 2; }
  local j; j="$(ibmcloud is instance "$1" --output json)"
  local primary_ip; primary_ip="$(jq -r '.primary_network_interface.primary_ipv4_address // "n/a"' <<<"$j")"
  echo "Primary IPv4: ${primary_ip}"
  echo "Floating IPs:"
  jq -r '.network_interfaces[].floating_ips[]?.address' <<<"$j" 2>/dev/null | sed 's/^/  - /' || echo "  - none"
}

#. ibmipls      -- List Floating IPs
ibmipls () {
  ibmcloud is floating-ips --output json \
    | jq -r '.[] | [.name, .id, .address, (.target.name // "unbound")] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-28s %-36s %-16s %s\n","Name","ID","Address","Target"}{printf "%-28s %-36s %-16s %s\n",$1,$2,$3,$4}'
}

#. ibmisgls     -- List security groups
ibmisgls () {
  ibmcloud is security-groups --output json \
    | jq -r '.[] | [.name, .id, (.vpc.name // "n/a"), .resource_group.name] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-32s %-36s %-18s %s\n","Name","ID","VPC","ResourceGroup"}{printf "%-32s %-36s %-18s %s\n",$1,$2,$3,$4}'
}

#. ibmisgrules  -- List rules for a security group
ibmisgrules () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmisgrules <security_group_id_or_name>"; return 2; }
  ibmcloud is security-group "$1" --output json \
    | jq -r '.rules[] | [.id, .direction, .protocol, (.port_min // "-"), (.port_max // "-"), (.remote.address // .remote.name // "-")] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-36s %-8s %-7s %-7s %-7s %s\n","RuleID","Dir","Proto","PortMin","PortMax","Remote"}{printf "%-36s %-8s %-7s %-7s %-7s %s\n",$1,$2,$3,$4,$5,$6}'
}

#. ibmisgruleadd -- Add rule: ibmisgruleadd <sg> <inbound|outbound> <tcp|udp|all|icmp> <portMin|-> <portMax|-> <remoteCIDR_or_sgID_or_all>
ibmisgruleadd () {
  [[ $# -eq 6 ]] || { echo "Usage: ibmisgruleadd <sg> <inbound|outbound> <tcp|udp|all|icmp> <portMin|-> <portMax|-> <remote>"; return 2; }
  local sg="$1" dir="$2" proto="$3" pmin="$4" pmax="$5" remote="$6"
  local args=( security-group-rule-add "$sg" "$dir" "$proto" )
  [[ "$proto" != "icmp" && "$pmin" != "-" ]] && args+=( --port-min "$pmin" )
  [[ "$proto" != "icmp" && "$pmax" != "-" ]] && args+=( --port-max "$pmax" )
  [[ "$remote" == "all" ]] && remote="0.0.0.0/0"
  args+=( --remote "$remote" )
  ibmcloud is "${args[@]}"
}

#. ibmisgrulerm  -- Remove rule by Rule ID from a security group
ibmisgrulerm () {
  [[ $# -eq 2 ]] || { echo "Usage: ibmisgrulerm <sg_id_or_name> <rule_id>"; return 2; }
  ibmcloud is security-group-rule-delete "$1" "$2"
}

#. ibmisginbounddenyall -- Remove all inbound allow rules on SG (default deny applies)
ibmisginbounddenyall () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmisginbounddenyall <sg_id_or_name>"; return 2; }
  local sg="$1"
  local j; j="$(ibmcloud is security-group "$sg" --output json)"
  mapfile -t inbound_ids < <(jq -r '.rules[] | select(.direction=="inbound") | .id' <<<"$j")
  for rid in "${inbound_ids[@]}"; do
    echo "Deleting inbound rule ${rid} from ${sg}"
    ibmcloud is security-group-rule-delete "$sg" "$rid"
  done
}

# ---------------------------------------------------------------------------
# IBM Kubernetes Service and OpenShift quick views
# ---------------------------------------------------------------------------

#. ibmksls      -- List IBM Kubernetes Service clusters
ibmksls () {
  ibmcloud ks clusters --json | jq -r '.[] | [.name, .id, .region, .worker_count, .state] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-28s %-36s %-10s %-6s %s\n","Name","ID","Region","Workers","State"}{printf "%-28s %-36s %-10s %-6s %s\n",$1,$2,$3,$4,$5}'
}

#. ibmrosa      -- List Red Hat OpenShift on IBM Cloud clusters
ibmrosa () {
  ibmcloud oc clusters --output json | jq -r '.[] | [.name, .id, .region, .ingressHostname, .state] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-28s %-36s %-10s %-40s %s\n","Name","ID","Region","Ingress","State"}{printf "%-28s %-36s %-10s %-40s %s\n",$1,$2,$3,$4,$5}'
}

# ---------------------------------------------------------------------------
# IAM users and access groups
# ---------------------------------------------------------------------------

#. ibmusers      -- List account users
ibmusers () {
  ibmcloud account users --output json | jq -r '.[] | [.user_id, .state, (.email // "n/a")] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-36s %-8s %s\n","UserID","State","Email"}{printf "%-36s %-8s %s\n",$1,$2,$3}'
}

#. ibmagls       -- List IAM access groups
ibmagls () {
  ibmcloud iam access-groups --output json | jq -r '.groups[] | [.name, .id] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-40s %s\n","Group","ID"}{printf "%-40s %s\n",$1,$2}'
}

#. ibmagusers    -- List users in an access group by name
ibmagusers () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmagusers <access_group_name>"; return 2; }
  ibmcloud iam access-group-users "$1" --output json | jq -r '.[] | [.iam_id, .type, .name] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-40s %-10s %s\n","IAM_ID","Type","Name"}{printf "%-40s %-10s %s\n",$1,$2,$3}'
}

#. ibmagpols     -- List policies attached to an access group
ibmagpols () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmagpols <access_group_name>"; return 2; }
  ibmcloud iam access-group-policies "$1" --output json | jq .
}

# ---------------------------------------------------------------------------
# Key Protect quick helpers
# ---------------------------------------------------------------------------

#. ibmkpset     -- Set KP instance ID env (KP_INSTANCE_ID) for plugin usage
ibmkpset () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmkpset <kp_instance_id>"; return 2; }
  export KP_INSTANCE_ID="$1"
  echo "KP_INSTANCE_ID set to ${KP_INSTANCE_ID}"
}

#. ibmkpls      -- List keys in current Key Protect instance
ibmkpls () {
  [[ -n "$KP_INSTANCE_ID" ]] || { echo "KP_INSTANCE_ID not set. Use ibmkpset <instance_id>"; return 1; }
  ibmcloud kp keys --instance-id "$KP_INSTANCE_ID" --output json | jq -r '.[] | [.id, .name, .state, .creationDate] | @tsv' \
    | awk -F'\t' 'BEGIN{printf "%-36s %-32s %-8s %s\n","KeyID","Name","State","Created"}{printf "%-36s %-32s %-8s %s\n",$1,$2,$3,$4}'
}

#. ibmkpget     -- Get a single key by ID or alias
ibmkpget () {
  [[ $# -eq 1 ]] || { echo "Usage: ibmkpget <key_id_or_alias>"; return 2; }
  [[ -n "$KP_INSTANCE_ID" ]] || { echo "KP_INSTANCE_ID not set. Use ibmkpset <instance_id>"; return 1; }
  ibmcloud kp key show "$1" --instance-id "$KP_INSTANCE_ID" --output json | jq .
}

# ---------------------------------------------------------------------------
# COS quick helpers, require ibmcloud cos configured via `ibmcloud cos config`
# ---------------------------------------------------------------------------

#. ibmcosbuckets -- List COS buckets
ibmcosbuckets () {
  ibmcloud cos bucket-list --output json | jq -r '.Buckets[] | .Name' 2>/dev/null | awk '{printf "  - %s\n",$0}'
}

#. ibmcosls      -- List objects in a bucket prefix: ibmcosls <bucket> [prefix]
ibmcosls () {
  [[ $# -ge 1 ]] || { echo "Usage: ibmcosls <bucket> [prefix]"; return 2; }
  local b="$1"; local p="${2:-}"
  if [[ -n "$p" ]]; then
    ibmcloud cos object-list --bucket "$b" --prefix "$p" --output json | jq -r '.Contents[]? | [.Key, .Size, .LastModified] | @tsv' \
      | awk -F'\t' 'BEGIN{printf "%-60s %12s %s\n","Key","Size","LastModified"}{printf "%-60s %12s %s\n",$1,$2,$3}'
  else
    ibmcloud cos object-list --bucket "$b" --output json | jq -r '.Contents[]? | [.Key, .Size, .LastModified] | @tsv' \
      | awk -F'\t' 'BEGIN{printf "%-60s %12s %s\n","Key","Size","LastModified"}{printf "%-60s %12s %s\n",$1,$2,$3}'
  fi
}

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

#. ibmplugins   -- Show installed IBM Cloud CLI plugins
ibmplugins () { ibmcloud plugin list; }

#. ibmclr       -- Clear IBM Cloud related environment variables
ibmclr () {
  local pat="${1:-IBMCLOUD|KP_INSTANCE_ID|COS_}"
  local vars; vars="$(env | awk -F= '{print $1}' | grep -E "$pat")"
  [[ -n "$vars" ]] || { echo "No matching vars for pattern: $pat"; return 0; }
  for v in $vars; do
    echo "unset $v"
    unset "$v"
  done
}

# ---------------------------------------------------------------------------
# Shortcuts
# ---------------------------------------------------------------------------

#. qsu          -- Quick set target to us-south and default RG
qsu () { ibmtarget us-south default; }

#. qsee         -- Quick set target to eu-de and default RG
qsee () { ibmtarget eu-de default; }

# ---------------------------------------------------------------------------
# End of file

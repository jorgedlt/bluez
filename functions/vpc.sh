#!/usr/bin/env bash
# vpc.sh — VPC instances, floating IPs, security groups and rules

# VPC instances list
ibmvmls() {
  ibmcloud is instances --output json \
    | jq -r '.[] | [.name, .id, .zone.name, .status, (.primary_network_interface.primary_ipv4_address // "n/a")] | @tsv' \
    | awk -F'\t' 'BEGIN{
        printf "%-32s %-36s %-12s %-10s %s\n","Name","ID","Zone","Status","PrimaryIPv4"
      }{
        printf "%-32s %-36s %-12s %-10s %s\n",$1,$2,$3,$4,$5
      }'
}

# VPC instance details
# Usage: ibmvmshow <instance_id_or_name>
ibmvmshow() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmvmshow <instance_id_or_name>"; return 2; }
  ibmcloud is instance "$1" --output json | jq .
}

# Start/Stop/Reboot
ibmvmstart() { [[ $# -eq 1 ]] || { echo "Usage: ibmvmstart <id_or_name>"; return 2; }; ibmcloud is instance-start "$1"; }
ibmvmstop()  { [[ $# -eq 1 ]] || { echo "Usage: ibmvmstop <id_or_name>";  return 2; }; ibmcloud is instance-stop  "$1"; }
ibmvmreboot(){ [[ $# -eq 1 ]] || { echo "Usage: ibmvmreboot <id_or_name>";return 2; }; ibmcloud is instance-reboot"$1"; }

# Show primary IPv4 and floating IPs
# Usage: ibmvmip <instance_id_or_name>
ibmvmip() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmvmip <instance_id_or_name>"; return 2; }
  local j; j="$(ibmcloud is instance "$1" --output json)"
  local primary_ip; primary_ip="$(jq -r '.primary_network_interface.primary_ipv4_address // "n/a"' <<<"$j")"
  echo "Primary IPv4: ${primary_ip}"
  echo "Floating IPs:"
  jq -r '.network_interfaces[].floating_ips[]?.address' <<<"$j" 2>/dev/null | sed 's/^/  - /' || echo "  - none"
}

# Floating IP list
ibmipls() {
  ibmcloud is floating-ips --output json \
    | jq -r '.[] | [.name, .id, .address, (.target.name // "unbound")] | @tsv' \
    | awk -F'\t' 'BEGIN{
        printf "%-28s %-36s %-16s %s\n","Name","ID","Address","Target"
      }{
        printf "%-28s %-36s %-16s %s\n",$1,$2,$3,$4
      }'
}

# Security groups list
ibmisgls() {
  ibmcloud is security-groups --output json \
    | jq -r '.[] | [.name, .id, (.vpc.name // "n/a"), .resource_group.name] | @tsv' \
    | awk -F'\t' 'BEGIN{
        printf "%-32s %-36s %-18s %s\n","Name","ID","VPC","ResourceGroup"
      }{
        printf "%-32s %-36s %-18s %s\n",$1,$2,$3,$4
      }'
}

# Security group rules
# Usage: ibmisgrules <sg_id_or_name>
ibmisgrules() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmisgrules <sg_id_or_name>"; return 2; }
  ibmcloud is security-group "$1" --output json \
    | jq -r '.rules[] | [.id, .direction, .protocol, (.port_min // "-"), (.port_max // "-"), (.remote.address // .remote.name // "-")] | @tsv' \
    | awk -F'\t' 'BEGIN{
        printf "%-36s %-8s %-7s %-7s %-7s %s\n","RuleID","Dir","Proto","PortMin","PortMax","Remote"
      }{
        printf "%-36s %-8s %-7s %-7s %-7s %s\n",$1,$2,$3,$4,$5,$6
      }'
}

# Add a rule
# Usage: ibmisgruleadd <sg> <inbound|outbound> <tcp|udp|all|icmp> <portMin|-> <portMax|-> <remoteCIDR|sgID|all>
ibmisgruleadd() {
  [[ $# -eq 6 ]] || { echo "Usage: ibmisgruleadd <sg> <inbound|outbound> <tcp|udp|all|icmp> <portMin|-> <portMax|-> <remote>"; return 2; }
  local sg="$1" dir="$2" proto="$3" pmin="$4" pmax="$5" remote="$6"
  local args=( security-group-rule-add "$sg" "$dir" "$proto" )
  [[ "$proto" != "icmp" && "$pmin" != "-" ]] && args+=( --port-min "$pmin" )
  [[ "$proto" != "icmp" && "$pmax" != "-" ]] && args+=( --port-max "$pmax" )
  [[ "$remote" == "all" ]] && remote="0.0.0.0/0"
  args+=( --remote "$remote" )
  ibmcloud is "${args[@]}"
}

# Remove a rule
# Usage: ibmisgrulerm <sg_id_or_name> <rule_id>
ibmisgrulerm() {
  [[ $# -eq 2 ]] || { echo "Usage: ibmisgrulerm <sg_id_or_name> <rule_id>"; return 2; }
  ibmcloud is security-group-rule-delete "$1" "$2"
}

# Remove all inbound allow rules (default deny applies)
# Usage: ibmisginbounddenyall <sg_id_or_name>
ibmisginbounddenyall() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmisginbounddenyall <sg_id_or_name>"; return 2; }
  local sg="$1"
  local j; j="$(ibmcloud is security-group "$sg" --output json)"
  mapfile -t inbound_ids < <(jq -r '.rules[] | select(.direction=="inbound") | .id' <<<"$j")
  for rid in "${inbound_ids[@]}"; do
    echo "Deleting inbound rule ${rid} from ${sg}"
    ibmcloud is security-group-rule-delete "$sg" "$rid"
  done
}

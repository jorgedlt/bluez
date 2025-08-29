#!/usr/bin/env bash
# k8s.sh — IBM Kubernetes Service and OpenShift listings

# List IBM Kubernetes Service clusters
# Usage: ibmksls
ibmksls() {
  ibmcloud ks clusters --json | jq -r '.[] | [.name, .id, .region, .worker_count, .state] | @tsv' \
    | awk -F'\t' 'BEGIN{
        printf "%-28s %-36s %-10s %-6s %s\n","Name","ID","Region","Workers","State"
      }{
        printf "%-28s %-36s %-10s %-6s %s\n",$1,$2,$3,$4,$5
      }'
}

# List Red Hat OpenShift clusters
# Usage: ibmrosa
ibmrosa() {
  ibmcloud oc clusters --output json | jq -r '.[] | [.name, .id, .region, .ingressHostname, .state] | @tsv' \
    | awk -F'\t' 'BEGIN{
        printf "%-28s %-36s %-10s %-40s %s\n","Name","ID","Region","Ingress","State"
      }{
        printf "%-28s %-36s %-10s %-40s %s\n",$1,$2,$3,$4,$5
      }'
}

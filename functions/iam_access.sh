#!/usr/bin/env bash
# iam_access.sh — IAM users and access groups (non-overlapping with existing rg/accounts)

# List account users
ibmusers() {
  ibmcloud account users --output json | jq -r '.[] | [.user_id, .state, (.email // "n/a")] | @tsv' \
    | awk -F'\t' 'BEGIN{
        printf "%-36s %-8s %s\n","UserID","State","Email"
      }{
        printf "%-36s %-8s %s\n",$1,$2,$3
      }'
}

# List IAM access groups
ibmagls() {
  ibmcloud iam access-groups --output json | jq -r '.groups[] | [.name, .id] | @tsv' \
    | awk -F'\t' 'BEGIN{
        printf "%-40s %s\n","Group","ID"
      }{
        printf "%-40s %s\n",$1,$2
      }'
}

# List users in an access group
# Usage: ibmagusers <access_group_name>
ibmagusers() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmagusers <access_group_name>"; return 2; }
  ibmcloud iam access-group-users "$1" --output json | jq -r '.[] | [.iam_id, .type, .name] | @tsv' \
    | awk -F'\t' 'BEGIN{
        printf "%-40s %-10s %s\n","IAM_ID","Type","Name"
      }{
        printf "%-40s %-10s %s\n",$1,$2,$3
      }'
}

# List policies attached to an access group
# Usage: ibmagpols <access_group_name>
ibmagpols() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmagpols <access_group_name>"; return 2; }
  ibmcloud iam access-group-policies "$1" --output json | jq .
}

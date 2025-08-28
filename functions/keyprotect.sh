#!/usr/bin/env bash
# keyprotect.sh — Key Protect helpers

# Set KP instance ID env for subsequent KP commands
# Usage: ibmkpset <kp_instance_id>
ibmkpset() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmkpset <kp_instance_id>"; return 2; }
  export KP_INSTANCE_ID="$1"
  echo "KP_INSTANCE_ID set to ${KP_INSTANCE_ID}"
}

# List keys in the current Key Protect instance
ibmkpls() {
  [[ -n "${KP_INSTANCE_ID:-}" ]] || { echo "KP_INSTANCE_ID not set. Use ibmkpset <instance_id>"; return 1; }
  ibmcloud kp keys --instance-id "$KP_INSTANCE_ID" --output json | jq -r '.[] | [.id, .name, .state, .creationDate] | @tsv' \
    | awk -F'\t' 'BEGIN{
        printf "%-36s %-32s %-8s %s\n","KeyID","Name","State","Created"
      }{
        printf "%-36s %-32s %-8s %s\n",$1,$2,$3,$4
      }'
}

# Show a single key
# Usage: ibmkpget <key_id_or_alias>
ibmkpget() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmkpget <key_id_or_alias>"; return 2; }
  [[ -n "${KP_INSTANCE_ID:-}" ]] || { echo "KP_INSTANCE_ID not set. Use ibmkpset <instance_id>"; return 1; }
  ibmcloud kp key show "$1" --instance-id "$KP_INSTANCE_ID" --output json | jq .
}

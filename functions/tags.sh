#!/usr/bin/env bash
# tags.sh — resource tagging helpers

# List tags on a named resource
# Usage: ibmtagls <resource_name>
ibmtagls() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmtagls <resource_name>"; return 2; }
  ibmcloud resource tags --resource-name "$1" --output json | jq .
}

# Attach tag(s) to a named resource
# Usage: ibmtagadd <resource_name> <tag1,tag2,...> [user|access]
ibmtagadd() {
  [[ $# -ge 2 ]] || { echo "Usage: ibmtagadd <resource_name> <tag1,tag2,...> [user|access]"; return 2; }
  local name="$1"; local tags="$2"; local ttype="${3:-user}"
  ibmcloud resource tag-attach --resource-name "$name" --tag-names "$tags" --tag-type "$ttype"
}

# Detach tag(s) from a named resource
# Usage: ibmtagrm <resource_name> <tag1,tag2,...> [user|access]
ibmtagrm() {
  [[ $# -ge 2 ]] || { echo "Usage: ibmtagrm <resource_name> <tag1,tag2,...> [user|access]"; return 2; }
  local name="$1"; local tags="$2"; local ttype="${3:-user}"
  ibmcloud resource tag-detach --resource-name "$name" --tag-names "$tags" --tag-type "$ttype"
}

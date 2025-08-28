#!/usr/bin/env bash
# iam.sh — resource groups & accounts (IAM-adjacent)

# List resource groups (mark current with *)
ibm_groups_ls() {
  local cur; cur="$(_current_rg_name)"

  ibmcloud resource groups --output json 2>/dev/null \
    | jq -r '.[] | [.name, .id, .state] | @tsv' \
    | while IFS=$'\t' read -r n i s; do
        local mark=""; [[ "$n" == "$cur" ]] && mark="* "
        printf "%s\t%s\t%s\n" "${mark}${n}" "$i" "$s"
      done \
    | _print_table "Resource Group\tID\tState" "30,36,10"
}

# Create group and target it
ibm_groups_mk() {
  local name="${1:-}"; [[ -n "$name" ]] || { echo "Usage: ibm_groups_mk <name>"; return 1; }
  ibmcloud resource group-create "$name" || return 1
  ibmcloud target -g "$name" >/dev/null 2>&1 || true
  ibm_groups_ls
}

# Remove group (exact name). Will move target if needed.
ibm_groups_rm() {
  local name="${1:-}"; [[ -n "$name" ]] || { echo "Usage: ibm_groups_rm <name>"; return 1; }
  [[ "$name" == "Default" ]] && { echo "Refusing to remove the Default group"; return 1; }
  local cur other
  cur="$(_current_rg_name)"
  if [[ "$cur" == "$name" ]]; then
    other="$(ibmcloud resource groups --output json 2>/dev/null | jq -r --arg n "$name" '[ .[] | select(.name!=$n) | .name ] | first // empty')"
    [[ -n "$other" ]] && ibmcloud target -g "$other" >/dev/null 2>&1 || true
  fi
  ibmcloud resource group-delete "$name" -f || return 1
  ibm_groups_ls
}

# Accounts list — CLI formats vary, so present a stable header and best effort fields
ibm_accounts_ls() {
  local header="Name\tIMS_ID\tGUID\tState"
  local widths="28,12,36,10"

  # Prefer JSON if available, else fallback to table parsing
  local j
  j="$(ibmcloud account list --output json 2>/dev/null || true)"
  if [[ -n "$j" && "$j" != "null" ]]; then
    printf "%s" "$j" \
      | jq -r '.[] | [
          (.Name // .name // "unknown"),
          ((.IMSAccountID // .ims_account_id // .AccountID // .account_number // .Number // "unknown") | tostring),
          (.AccountGUID // .account_guid // .account_id // .guid //
            (try ((.CRN // .crn) | capture("account:(?<id>[^:]+)$").id) catch "unknown")),
          (.State // .state // "unknown")
        ] | @tsv' \
      | _print_table "$header" "$widths"
    return
  fi

  ibmcloud account list 2>/dev/null \
    | awk -F'|' 'NR>2 && NF {gsub(/^[ \t]+|[ \t]+$/, "", $1); gsub(/^[ \t]+|[ \t]+$/, "", $2); print $1 "\tunknown\tunknown\t" $2}' \
    | _print_table "$header" "$widths"
}

# Combined status
ibm_status_show() {
  ibm_whoami_show; echo
  ibm_groups_ls;  echo
  ibm_accounts_ls
}

# Backcompat shims
ibm_groups()  { ibm_groups_ls; }
ibm_accounts(){ ibm_accounts_ls; }
ibm_status()  { ibm_status_show; }

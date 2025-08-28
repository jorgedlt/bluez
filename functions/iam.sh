# functions/iam.sh
#!/usr/bin/env bash
# iam.sh — resource groups & accounts (IAM-adjacent), renamed functions

# ----- internal soft dep check (no exit) ------------------------------------
__iam_need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; return 1; }
}

# ----- helpers --------------------------------------------------------------
_iam_current_rg() {
  ibmcloud target 2>/dev/null | awk -F': ' '/^Resource group:/ {print $2}'
}

_iam_try_target_rg() {
  local rg="$1"
  [[ -n "$rg" ]] || return 1
  ibmcloud resource groups --output json 2>/dev/null \
    | jq -e --arg rg "$rg" '.[] | select(.name==$rg)' >/dev/null || return 1
  ibmcloud target -g "$rg" >/dev/null 2>&1 || return 1
  return 0
}

# ----- Resource Groups ------------------------------------------------------
# List resource groups (pretty table, safe)
ibmrgls() {
  __iam_need ibmcloud || return 1
  __iam_need jq       || return 1

  local j
  if ! j="$(ibmcloud resource groups --output json 2>/dev/null)"; then
    echo "Failed to query resource groups. Are you logged in? (ibmlogin)" >&2
    return 1
  fi

  if [[ -z "$j" || "$j" == "null" ]]; then
    echo "No resource groups found."
    return 0
  fi

  local cur; cur="$(_iam_current_rg)"

  printf "%-24s | %-36s | %-8s\n" "Resource Group" "ID" "State"
  echo "$j" \
    | jq -r '.[] | [.name, .id, .state] | @tsv' \
    | awk -F'\t' -v cur="$cur" '{
        mark = ($1==cur) ? "*" : " ";
        printf "%s%-23s | %-36s | %-8s\n", mark, $1, $2, $3
      }'
}

# Create a resource group and optionally target it
# Usage: ibmrgmk <name> [--target]
ibmrgmk() {
  __iam_need ibmcloud || return 1
  local name="$1"
  shift || true
  local do_target=0
  [[ "$1" == "--target" ]] && do_target=1

  [[ -n "$name" ]] || { echo "Usage: ibmrgmk <name> [--target]" >&2; return 1; }

  if ibmcloud resource groups --output json 2>/dev/null \
       | jq -e --arg n "$name" '.[] | select(.name==$n)' >/dev/null; then
    echo "Resource group already exists: $name"
  else
    if ! ibmcloud resource group-create "$name"; then
      echo "Failed to create resource group: $name" >&2
      return 1
    fi
  fi

  (( do_target )) && ibmcloud target -g "$name" >/dev/null 2>&1 || true
  ibmrgls
}

# Delete a resource group by exact name
# Usage: ibmrgrm <name> [--force]
ibmrgrm() {
  __iam_need ibmcloud || return 1
  local name="$1"
  shift || true
  local force=0
  [[ "$1" == "--force" || "$1" == "-f" ]] && force=1

  [[ -n "$name" ]] || { echo "Usage: ibmrgrm <name> [--force]" >&2; return 1; }
  [[ "$name" == "Default" ]] && { echo "Refusing to remove the Default group" >&2; return 1; }

  if ! ibmcloud resource groups --output json 2>/dev/null \
        | jq -e --arg n "$name" '.[] | select(.name==$n)' >/dev/null; then
    echo "Resource group not found: $name" >&2
    return 1
  fi

  local cur other
  cur="$(_iam_current_rg)"
  if [[ "$cur" == "$name" ]]; then
    other="$(ibmcloud resource groups --output json 2>/dev/null | jq -r --arg n "$name" '
      [ .[] | select(.name != $n) | .name ] | first // empty
    ')"
    [[ -n "$other" ]] && ibmcloud target -g "$other" >/dev/null 2>&1 || true
  fi

  if (( force )); then
    ibmcloud resource group-delete "$name" -f || { echo "Failed to delete: $name" >&2; return 1; }
  else
    ibmcloud resource group-delete "$name"    || { echo "Failed to delete: $name" >&2; return 1; }
  fi

  ibmrgls
}

# ----- Accounts (best-effort fields) ---------------------------------------
ibmaccountsls() {
  local header="Name\tIMS_ID\tGUID\tState"
  local widths="28,12,36,10"

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

# ----- Combined status ------------------------------------------------------
ibmstatus() {
  ibmwhoami; echo
  ibmrgls;   echo
  ibmaccountsls
}

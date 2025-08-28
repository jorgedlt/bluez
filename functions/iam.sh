#!/usr/bin/env bash
# functions/iam.sh — Resource Groups & IAM utilities
#
# Scope:
#   - List/Create/Delete resource groups
#   - (room for user/role/policy helpers later)
#
# Requires:
#   - ibmcloud CLI
#   - jq
#
# Conventions:
#   - Never 'exit' from functions (so interactive shells don’t die)
#   - On failure: print a clear message to stderr and 'return' non-zero

# ----- internal soft dep check (no exit) ------------------------------------
__iam_need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; return 1; }
}

# ----- helpers --------------------------------------------------------------
# Return currently targeted resource group name, or empty if none
_iam_current_rg() {
  ibmcloud target 2>/dev/null | awk -F': ' '/^Resource group:/ {print $2}'
}

# Target the given resource group if it exists (quietly); return 0/1
_iam_try_target_rg() {
  local rg="$1"
  [[ -n "$rg" ]] || return 1
  ibmcloud resource groups --output json 2>/dev/null \
    | jq -e --arg rg "$rg" '.[] | select(.name==$rg)' >/dev/null || return 1
  ibmcloud target -g "$rg" >/dev/null 2>&1 || return 1
  return 0
}

# ----- Commands -------------------------------------------------------------
# List resource groups (pretty table, safe)
ibm_groups_ls() {
  __iam_need ibmcloud || return 1
  __iam_need jq       || return 1

  local j
  if ! j="$(ibmcloud resource groups --output json 2>/dev/null)"; then
    echo "Failed to query resource groups. Are you logged in? (ibm_login)" >&2
    return 1
  fi

  if [[ -z "$j" || "$j" == "null" ]]; then
    echo "No resource groups found."
    return 0
  fi

  # Determine currently targeted RG to mark with '*'
  local cur; cur="$(_iam_current_rg)"

  # Header
  printf "%-24s | %-36s | %-8s\n" "Resource Group" "ID" "State"

  # Rows
  echo "$j" \
    | jq -r '.[] | [.name, .id, .state] | @tsv' \
    | awk -F'\t' -v cur="$cur" '{
        mark = ($1==cur) ? "*" : " ";
        printf "%s%-23s | %-36s | %-8s\n", mark, $1, $2, $3
      }'
}

# Create a resource group and (optionally) target it
# Usage: ibm_groups_mk <name> [--target]
ibm_groups_mk() {
  __iam_need ibmcloud || return 1
  local name="$1"
  shift || true
  local do_target=0
  [[ "$1" == "--target" ]] && do_target=1

  [[ -n "$name" ]] || { echo "Usage: ibm_groups_mk <name> [--target]" >&2; return 1; }

  # Exists?
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
  ibm_groups_ls
}

# Delete a resource group by exact name
# Usage: ibm_groups_rm <name> [--force]
ibm_groups_rm() {
  __iam_need ibmcloud || return 1
  local name="$1"
  shift || true
  local force=0
  [[ "$1" == "--force" || "$1" == "-f" ]] && force=1

  [[ -n "$name" ]] || { echo "Usage: ibm_groups_rm <name> [--force]" >&2; return 1; }
  [[ "$name" == "Default" ]] && { echo "Refusing to remove the Default group" >&2; return 1; }

  # Verify exists
  if ! ibmcloud resource groups --output json 2>/dev/null \
        | jq -e --arg n "$name" '.[] | select(.name==$n)' >/dev/null; then
    echo "Resource group not found: $name" >&2
    return 1
  fi

  # If currently targeted, hop to another group first to be nice
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

  ibm_groups_ls
}

# Friendly status wrapper (uses your existing whoami func if present)
ibm_iam_status() {
  type -t ibm_whoami_show >/dev/null 2>&1 && ibm_whoami_show
  echo
  ibm_groups_ls
}

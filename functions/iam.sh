#!/usr/bin/env bash
# functions/iam.sh — stub for IAM helpers

 # ...existing code...
#!/usr/bin/env bash
# IAM & Resource Group helpers
# Requires: ibmcloud, jq

# ---------- deps ----------
_iam_need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; return 1; }
}

# ---------- helpers ----------
_iam_current_rg() {
  ibmcloud target 2>/dev/null | awk -F': *' '/^Resource group:/ {print $2}'
}

# Try to target a resource group by name (safe with set -u)
_iam_try_target_rg() {
  local rg="${1-}"
  [[ -n "$rg" ]] || return 1

  ibmcloud resource groups --output json 2>/dev/null \
    | jq -e --arg rg "$rg" '.[] | select(.name==$rg)' >/dev/null || return 1

  ibmcloud target -g "$rg" >/dev/null 2>&1 || return 1
  return 0
}

# ---------- Resource Groups ----------
# Pretty list, robust even if JSON is missing/invalid
ibmrgls() {
  _iam_need ibmcloud || return 1
  _iam_need jq || return 1

  local j rc
  j="$(ibmcloud resource groups --output json 2>/dev/null || true)"; rc=$?

  # If we got nothing or invalid JSON, fall back to plain table
  if [[ $rc -ne 0 || -z "$j" ]] || ! jq -e . >/dev/null 2>&1 <<<"$j"; then
    # Fallback to the human table; mark current
    local cur; cur="$(_iam_current_rg)"
    printf "%-24s | %-36s | %-8s\n" "Resource Group" "ID" "State"
    ibmcloud resource groups 2>/dev/null \
      | awk 'NR>2 && NF' \
      | awk -v cur="$cur" -F'  +' '
          {name=$1; state=$2}
          name!=""{
            mark=(name==cur)?"* ":"  "
            printf "%-24s | %-36s | %-8s\n", mark name, "-", state
          }'
    return 0
  fi

  # If JSON is valid but empty/null
  if jq -e 'type=="array" and length==0' >/dev/null 2>&1 <<<"$j"; then
    echo "No resource groups found."
    return 0
  fi

  local cur; cur="$(_iam_current_rg)"
  printf "%-24s | %-36s | %-8s\n" "Resource Group" "ID" "State"
  echo "$j" \
    | jq -r '.[] | [.name, .id, .state] | @tsv' \
    | while IFS=$'\t' read -r name id state; do
        printf "%-24s | %-36s | %-8s\n" \
          "$( [[ "$name" == "$cur" ]] && printf "* %s" "$name" || printf "  %s" "$name")" \
          "$id" "$state"
      done
}

# Show one RG
ibmrgshow() {
  [[ $# -eq 1 ]] || { echo "Usage: ibmrgshow <resource_group_name>"; return 2; }
  _iam_need ibmcloud || return 1
  _iam_need jq || return 1
  ibmcloud resource group "$1" --output json | jq .
}

# Create RG
# Usage: ibmrgmk <name> [--target|-t]
ibmrgmk() {
  _iam_need ibmcloud || return 1
  _iam_need jq || return 1

  local name="" set_target=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --target|-t) set_target=1; shift ;;
      *) if [[ -z "$name" ]]; then name="$1"; shift; else c_err "Unexpected arg: $1"; return 2; fi ;;
    esac
  done
  [[ -n "$name" ]] || { c_warn "Usage: ibmrgmk <name> [--target|-t]"; return 2; }

  if ibmcloud resource groups --output json 2>/dev/null \
       | jq -e --arg n "$name" '.[] | select(.name==$n)' >/dev/null; then
    c_note "Resource group already exists: $name"
  else
    ibmcloud resource group-create "$name" || return 1
    c_ok "Created resource group: $name"
  fi

  sleep 2
  ibmrgls

  if (( set_target )); then
    if _iam_try_target_rg "$name"; then
      c_ok "Targeted resource group '$name'."
      command -v ibmwhoami >/dev/null 2>&1 && ibmwhoami || true
    else
      c_err "Created but could not target resource group '$name'."
    fi
  fi
}

# Delete RG
# Usage: ibmrgrm <name> [--force|-f]
ibmrgrm() {
  _iam_need ibmcloud || return 1
  _iam_need jq || return 1

  local name="" force=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force|-f) force=1; shift ;;
      *) if [[ -z "$name" ]]; then name="$1"; shift; else echo "Unexpected arg: $1" >&2; return 2; fi ;;
    esac
  done
  [[ -n "$name" ]] || { echo "Usage: ibmrgrm <name> [--force|-f]"; return 2; }
  [[ "$name" == "Default" ]] && { echo "Refusing to remove the Default group"; return 1; }

  if ! ibmcloud resource groups --output json 2>/dev/null \
        | jq -e --arg n "$name" '.[] | select(.name==$n)' >/dev/null; then
    echo "Resource group not found: $name"
    return 1
  fi

  local cur other
  cur="$(_iam_current_rg)"
  if [[ "$cur" == "$name" ]]; then
    other="$(ibmcloud resource groups --output json 2>/dev/null \
              | jq -r --arg n "$name" '[ .[] | select(.name!=$n) | .name ] | first // empty')"
    [[ -n "$other" ]] && ibmcloud target -g "$other" >/dev/null 2>&1 || true
  fi

  if (( force )); then
    ibmcloud resource group-delete "$name" -f || return 1
  else
    ibmcloud resource group-delete "$name" || return 1
  fi

  ibmrgls
}

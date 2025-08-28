# init.sh
#!/usr/bin/env bash
# init.sh — shared configuration & helpers for IBM Cloud bash toolkit

# -------- Defaults (user-overridable via environment) --------
: "${IBMC_API_ENDPOINT:=https://cloud.ibm.com}"
: "${IBMC_REGION:=us-south}"
: "${IBMC_RG:=Default}"

# Per-account API key files (adjust to your paths)
: "${IBMC_KEYFILE_SANDBOX:=$HOME/ibmcloud_api_key_sandbox.json}"   # IMS 3127011
: "${IBMC_KEYFILE_EPOSIT:=$HOME/ibmcloud_api_key.json}"            # IMS 2617128

# Default account selector used by ibmlogin when -a is omitted
: "${IBMC_DEFAULT:=sandbox}"

# -------- Dependency checks --------
_need() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; return 1; }
}
_die() { echo "ERROR: $*" >&2; return 1; }

_need ibmcloud || return 1
_need jq || return 1
_need awk || return 1
_need sed || return 1
_need tr || return 1

# -------- Helpers --------
_read_key() {
  local f="$1"
  [[ -f "$f" ]] || _die "API key file not found: $f"
  jq -r '.apikey // empty' "$f" | awk 'NF' || _die "No apikey in $f"
}

_keyfile_for() {
  case "$1" in
    sandbox|3127011) printf '%s' "$IBMC_KEYFILE_SANDBOX" ;;
    eposit|2617128)  printf '%s' "$IBMC_KEYFILE_EPOSIT"  ;;
    /*|./*|../*)      printf '%s' "$1" ;;
    *)               printf '%s' "$IBMC_KEYFILE_SANDBOX" ;;
  esac
}

_current_rg_name() {
  ibmcloud target 2>/dev/null | awk -F': ' '/^Resource group:/ {print $2}'
}

_current_rg_id() {
  local name; name="$(_current_rg_name)"
  [[ -n "$name" && "$name" != "No resource group targeted, use '\''ibmcloud target -g RESOURCE_GROUP'\''" ]] || return 1
  ibmcloud resource groups --output json 2>/dev/null \
    | jq -r --arg n "$name" '.[] | select(.name==$n) | .id' | awk 'NF'
}

_ensure_region() {
  local region="${1:-$IBMC_REGION}"
  ibmcloud target -r "$region" >/dev/null 2>&1 || true
}

_ensure_rg() {
  local cur; cur="$(_current_rg_name)"
  if [[ -z "$cur" || "$cur" =~ ^No\ resource\ group\ targeted ]]; then
    if ibmcloud resource groups --output json 2>/dev/null \
         | jq -e --arg rg "$IBMC_RG" '.[] | select(.name==$rg)' >/dev/null; then
      ibmcloud target -g "$IBMC_RG" >/dev/null 2>&1 || true
    fi
  fi
}

# Pretty table helper (prints header and then rows from stdin; columns are tab-separated)
# Usage:  rows | _print_table "Col1\tCol2\tCol3" "30,20,10"
_print_table() {
  local header="$1" widths_csv="$2"
  local IFS=$'\t' cols=( $header )
  IFS=',' read -r -a widths <<<"$widths_csv"

  for i in "${!cols[@]}"; do
    printf "%-${widths[$i]}s" "${cols[$i]}"
    [[ $i -lt $(( ${#cols[@]} - 1 )) ]] && printf " | "
  done
  printf "\n"

  for i in "${!cols[@]}"; do
    printf "%-${widths[$i]}s" "$(printf '%*s' "${widths[$i]}" '' | tr ' ' '-')"
    [[ $i -lt $(( ${#cols[@]} - 1 )) ]] && printf "-+-"
  done
  printf "\n"

  while IFS=$'\t' read -r -a row; do
    [[ ${#row[@]} -eq 0 ]] && continue
    for i in "${!row[@]}"; do
      printf "%-${widths[$i]}s" "${row[$i]}"
      [[ $i -lt $(( ${#row[@]} - 1 )) ]] && printf " | "
    done
    printf "\n"
  done
}

#!/usr/bin/env bash
# login.sh, login and account helpers

: "${RED:=$'\033[31m'}"
: "${GREEN:=$'\033[32m'}"
: "${YELLOW:=$'\033[33m'}"
: "${CYAN:=$'\033[36m'}"
: "${BOLD:=$'\033[1m'}"
: "${RESET:=$'\033[0m'}"

# Minimal dep checker
_need() { command -v "$1" >/dev/null 2>&1 || { printf "%sMissing dependency: %s%s\n" "$RED" "$1" "$RESET" >&2; return 1; }; }

: "${IBMC_API_ENDPOINT:=https://cloud.ibm.com}"
: "${IBMC_REGION:=us-south}"
: "${IBMC_RG:=default}"
: "${IBMC_DEFAULT:=sandbox}"

# Build an in-memory map from keyfiles in $HOME following pattern:
#   ibmcloud_key_<alias>-NNN.json  (e.g., ibmcloud_key_legacy-128.json)
_ibm_key_index() {
  shopt -s nullglob
  local f base alias last3
  for f in "$HOME"/ibmcloud_key_*.json; do
    base="$(basename "$f")"
    if [[ "$base" =~ ^ibmcloud_key_(.+)-([0-9]{3})\.json$ ]]; then
      alias="${BASH_REMATCH[1],,}"
      last3="${BASH_REMATCH[2]}"
      printf "%s\t%s\t%s\n" "$alias" "$last3" "$f"
    fi
  done
  shopt -u nullglob
}

# Resolve selector to keyfile without hardcoding full GUIDs.
# Accepts:
#   - path to a readable file
#   - alias match (legacy, sandbox, devalpha, devbeta, etc.)
#   - IMS last-3 digits (128, 011, 729, 651)
#   - partial alias substrings
_keyfile_for() {
  local sel="$1"
  [[ -n "$sel" ]] || return 1

  # direct path
  if [[ -r "$sel" ]]; then printf '%s\n' "$sel"; return 0; fi

  local s="${sel,,}"
  local rows row alias last3 file best=""
  mapfile -t rows < <(_ibm_key_index)

  # exact by last3 (numeric 3)
  if [[ "$s" =~ ^[0-9]{3}$ ]]; then
    for row in "${rows[@]}"; do
      alias="${row%%$'\t'*}"; row="${row#*$'\t'}"
      last3="${row%%$'\t'*}"; file="${row#*$'\t'}"
      if [[ "$last3" == "$s" ]]; then best="$file"; break; fi
    done
    [[ -n "$best" ]] && { printf '%s\n' "$best"; return 0; }
  fi

  # exact alias
  for row in "${rows[@]}"; do
    alias="${row%%$'\t'*}"; row="${row#*$'\t'}"
    file="${row#*$'\t'}"
    if [[ "$alias" == "$s" ]]; then printf '%s\n' "$file"; return 0; fi
  done

  # common synonyms -> canonical alias
  case "$s" in
    legacy|legacy-128) s="legacy" ;;
    sandbox|sandbox-011) s="sandbox" ;;
    devalpha|dev-alpha|alpha) s="devalpha" ;;
    devbeta|dev-beta|beta) s="devbeta" ;;
  esac

  # substring alias
  for row in "${rows[@]}"; do
    alias="${row%%$'\t'*}"; row="${row#*$'\t'}"
    file="${row#*$'\t'}"
    if [[ "$alias" == *"$s"* ]]; then best="$file"; break; fi
  done
  [[ -n "$best" ]] && { printf '%s\n' "$best"; return 0; }

  return 1
}

# Usage: ibmaccmap  (show discovered aliases -> files, masked)
ibmaccmap() {
  local rows row alias last3 file
  printf "%-12s %-6s %s\n" "Alias" "IMS" "Keyfile"
  printf "%-12s %-6s %s\n" "-----" "----" "-------"
  while IFS=$'\t' read -r alias last3 file; do
    printf "%-12s %-6s %s\n" "$alias" "$last3" "$file"
  done < <(_ibm_key_index)
}

# Usage: ibmlogin [key-or-alias] [--region REGION] [--rg GROUP]
ibmlogin() {
  _need ibmcloud || return 1
  local sel="" region="" rg=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --region) region="$2"; shift 2 ;;
      --rg)     rg="$2";     shift 2 ;;
      *)        sel="$1";    shift    ;;
    esac
  done

  local keyf
  if [[ -n "$sel" ]]; then
    keyf="$(_keyfile_for "$sel")" || { printf "%sNo usable keyfile for '%s'%s\n" "$RED" "$sel" "$RESET" >&2; return 1; }
  else
    keyf="$(_keyfile_for "$IBMC_DEFAULT")" || { printf "%sDefault keyfile not found%s\n" "$RED" "$RESET" >&2; return 1; }
  fi

  echo "Logging in with key: $keyf"
  ibmcloud login -a "${IBMC_API_ENDPOINT}" --apikey @"$keyf" -q || return 1

  [[ -n "$region" ]] || region="$IBMC_REGION"
  [[ -n "$rg"     ]] || rg="$IBMC_RG"
  [[ -n "$region" ]] && ibmcloud target -r "$region" >/dev/null 2>&1 || true
  [[ -n "$rg"     ]] && ibmcloud target -g "$rg"     >/dev/null 2>&1 || true
  ibmwhoami
}

# Usage: ibmwhoami
ibmwhoami() {
  _need ibmcloud || return 1
  local t; t="$(ibmcloud target 2>/dev/null || true)"
  [[ -n "$t" ]] || { printf "%sNot logged in.%s\n" "$YELLOW" "$RESET" >&2; return 1; }

  local api region user account rg
  api="$(awk -F': *' '/^API endpoint:/ {print $2}' <<<"$t")"
  region="$(awk -F': *' '/^Region:/ {print $2}' <<<"$t")"
  user="$(awk -F': *' '/^User:/ {print $2}' <<<"$t")"
  account="$(awk -F': *' '/^Account:/ {print $2}' <<<"$t")"
  rg="$(awk -F': *' '/^Resource group:/ {print $2}' <<<"$t")"
  [[ -n "$api" ]]    || api="unknown"
  [[ -n "$region" ]] || region="unknown"
  [[ -n "$user" ]]   || user="unknown"
  [[ -n "$account" ]]|| account="unknown"
  if [[ -z "$rg" || "$rg" =~ ^No\ resource\ group\ targeted ]]; then rg="none"; fi

  printf "%sAPI endpoint:%s %s\n"     "${BOLD}${CYAN}" "${RESET}" "$api"
  printf "%sRegion:%s       %s\n"     "${BOLD}${CYAN}" "${RESET}" "$region"
  printf "%sUser:%s         %s\n"     "${BOLD}${CYAN}" "${RESET}" "$user"
  printf "%sAccount:%s      %s\n"     "${BOLD}${CYAN}" "${RESET}" "$account"
  printf "%sResource group:%s %s\n"   "${BOLD}${CYAN}" "${RESET}" "$rg"
}

# Usage: ibmaccls
ibmaccls() { _need ibmcloud || return 1; ibmcloud account list; }

# Usage: ibmaccswap <acctName|alias|IMS-last3|keyfile>
ibmaccswap() {
  _need ibmcloud || return 1
  local sel="$1"
  [[ -n "$sel" ]] || { echo "Usage: ibmaccswap <acctName|alias|IMS-last3|keyfile>" >&2; return 1; }
  local keyf; keyf="$(_keyfile_for "$sel")" || { echo "${RED}No usable keyfile for $sel${RESET}" >&2; return 1; }
  echo "Swapping account using keyfile: $keyf"
  ibmcloud login --apikey @"$keyf" -q || return 1
  ibmwhoami
}

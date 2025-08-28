# functions/login.sh
#!/usr/bin/env bash
# login.sh — login & authentication helpers (renamed functions)

# ibmlogin [-a acct|keyfile] [-r region] [-g rg] [-s] [-c sso-account]
# Notes:
#   - With API key login, do NOT pass -c (account is implied by the key).
#   - -s uses SSO and can accept -c <IMS_ID> to preselect account.
ibmlogin() {
  local acct="$IBMC_DEFAULT" region="$IBMC_REGION" rg="$IBMC_RG" use_sso=0 sso_account="" keyfile=""
  while getopts ":a:r:g:sc:K:" opt; do
    case "$opt" in
      a) acct="$OPTARG" ;;
      r) region="$OPTARG" ;;
      g) rg="$OPTARG" ;;
      s) use_sso=1 ;;
      c) sso_account="$OPTARG" ;;
      K) keyfile="$OPTARG" ;;
      *) ;;
    esac
  done

  _ensure_region "$region"

  if (( use_sso )); then
    if [[ -n "$sso_account" ]]; then
      ibmcloud login --sso -a "$IBMC_API_ENDPOINT" -c "$sso_account" -r "$region" || return 1
    else
      ibmcloud login --sso -a "$IBMC_API_ENDPOINT" -r "$region" || return 1
    fi
  else
    [[ -n "$keyfile" ]] || keyfile="$(_keyfile_for "$acct")"
    local key; key="$(_read_key "$keyfile")" || return 1
    ibmcloud login --apikey "$key" -a "$IBMC_API_ENDPOINT" -r "$region" || return 1
  fi

  _ensure_region "$region"
  _ensure_rg

  ibmwhoami
}

# ibmswitchaccount <sandbox|eposit|IMS_ID|/path/key.json>  [-s]
ibmswitchaccount() {
  local sel="${1:-}"; shift || true
  [[ -n "$sel" ]] || { echo "Usage: ibmswitchaccount <acct|keyfile> [-s]"; return 1; }
  local use_sso=0; [[ "${1:-}" == "-s" ]] && use_sso=1

  _ensure_region "$IBMC_REGION"

  if (( use_sso )); then
    ibmcloud login --sso -a "$IBMC_API_ENDPOINT" -c "$sel" -r "$IBMC_REGION" || return 1
  else
    local keyfile="$(_keyfile_for "$sel")"
    local key; key="$(_read_key "$keyfile")" || return 1
    ibmcloud login --apikey "$key" -a "$IBMC_API_ENDPOINT" -r "$IBMC_REGION" || return 1
  fi

  _ensure_region "$IBMC_REGION"
  _ensure_rg
  ibmwhoami
}

# Pretty "who am I"
ibmwhoami() {
  ibmcloud target 2>/dev/null | awk '
    /^API endpoint/ ||
    /^Region/ ||
    /^User/ ||
    /^Account/ ||
    /^Resource group/ {print}'
}

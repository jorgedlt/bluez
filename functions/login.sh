#!/usr/bin/env bash
# login.sh — login & authentication helpers

# ibmlogin [-a acct|keyfile] [-r region] [-g rg] [-s] [-c sso-account]
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

# ibmaccls — list accounts, robust across shapes
ibmaccls() {
  local j out
  j="$(ibmcloud account list --output json 2>/dev/null || true)"
  if [[ -n "$j" && "$j" != "null" ]]; then
    out="$(printf '%s' "$j" | jq -r '
      def rows:
        if type=="array" then .[]
        elif type=="object" and (has("Guid") or has("LinkedAccounts")) then
          . as $p | ([$p] + (.LinkedAccounts // []))[]
        else . end;
      rows
      | {name:(.name//.Name), id:(.account_id//.Guid),
         state:(.state//.State//"unknown"),
         owner:(.owner_iam_id//.owneribmid//.owner_ibmid//.OwnerIamId//.OwnerIbmid//"n/a")}
      | select(.name and .id) | [.name,.id,.state,.owner] | @tsv
    ' 2>/dev/null)"
    if [[ -n "$out" ]]; then
      awk -F'\t' 'BEGIN{
        printf "%-40s %-36s %-10s %s\n","Name","AccountID","State","Owner"
      }{ printf "%-40s %-36s %-10s %s\n",$1,$2,$3,$4 }' <<<"$out"
      return 0
    fi
  fi
  ibmcloud account list 2>/dev/null \
  | awk 'NR<=2{next} NF{print}' \
  | awk 'BEGIN{
      printf "%-40s %-36s %-10s %s\n","Name","AccountID","State","Owner"
    }{
      n=split($0,a,/[[:space:]]{2,}/); name=a[1]; acct=a[2]; state=a[3]; owner=a[4]; if(owner=="")owner="n/a";
      printf "%-40s %-36s %-10s %s\n",name,acct,state,owner
    }'
}

# ibmaccswap [-s] <account_name|account_id|/path/key.json>
# Default: API key re-login using resolved keyfile. With -s: SSO + account switch.
ibmaccswap() {
  local use_sso=0 sel=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -s|--sso) use_sso=1; shift ;;
      *) sel="$1"; shift ;;
    esac
  done
  [[ -n "$sel" ]] || { echo "Usage: ibmaccswap [-s] <acct|keyfile>"; return 1; }

  if (( use_sso )); then
    _ensure_region "$IBMC_REGION"
    ibmcloud login --sso -a "$IBMC_API_ENDPOINT" -r "$IBMC_REGION" || return 1
    # try to switch by account id resolved from name
    local acct_id
    acct_id="$(ibmcloud account list --output json 2>/dev/null \
      | jq -r --arg x "$sel" '
          def lc(s): (s // "" | tostring | ascii_downcase);
          .[] | select(lc(.name)==lc($x) or lc(.account_id)==lc($x)) | .account_id' \
      | head -n1)"
    [[ -n "$acct_id" ]] || { echo "Could not resolve account: $sel" >&2; return 1; }
    ibmcloud account switch -a "$acct_id" || return 1
    _ensure_region "$IBMC_REGION"; _ensure_rg; ibmwhoami; return 0
  fi

  # Non-interactive API key flow
  local keyfile=""
  if [[ "$sel" == */* || "$sel" == *.json ]]; then
    [[ -r "$sel" ]] && keyfile="$sel"
  fi
  [[ -n "$keyfile" ]] || keyfile="$(_keyfile_for "$sel")"
  [[ -r "$keyfile" ]] || { echo "No readable keyfile for '$sel'." >&2; return 1; }

  local key; key="$(_read_key "$keyfile")" || return 1
  _ensure_region "$IBMC_REGION"
  ibmcloud login --apikey "$key" -a "$IBMC_API_ENDPOINT" -r "$IBMC_REGION" || return 1
  _ensure_region "$IBMC_REGION"; _ensure_rg; ibmwhoami
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

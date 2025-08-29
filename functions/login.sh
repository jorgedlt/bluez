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

# ibmaccls — list all IBM Cloud accounts accessible to the user
# ibmaccls() {
#   ibmcloud account list --output json 2>/dev/null \
#   | jq -r '.[] | [.Name, .Guid, .State, (.OwnerIamId // "n/a")] | @tsv' \
#   | awk -F'\t' 'BEGIN{
#       printf "%-40s %-36s %-10s %s\n","Name","AccountID","State","Owner"
#     }{
#       printf "%-40s %-36s %-10s %s\n",$1,$2,$3,$4
#     }'
# }

# ibmaccls — list all IBM Cloud accounts accessible to the user (handles both JSON shapes)
ibmaccls() {
  # Try JSON first
  local j out
  j="$(ibmcloud account list --output json 2>/dev/null || true)"

  if [[ -n "$j" && "$j" != "null" ]]; then
    out="$(printf '%s' "$j" | jq -r '
      # Normalize both shapes:
      # 1) Old: [{"account_id": "...", "name": "...", "state": "...", "owner_ibmid": "..."}]
      # 2) New: {"Guid": "...", "Name": "...", "State": "...", "OwnerIamId": "...", "LinkedAccounts":[{...}]}
      def rows:
        if type=="array" then .[]
        elif type=="object" and (has("Guid") or has("LinkedAccounts")) then
          . as $p | ([$p] + (.LinkedAccounts // []))[]
        else . end;

      rows
      | {
          name:  (.name        // .Name),
          id:    (.account_id  // .Guid),
          state: (.state       // .State       // "unknown"),
          owner: (.owner_iam_id // .owneribmid // .owner_ibmid // .OwnerIamId // .OwnerIbmid // "n/a")
        }
      | select(.name and .id)
      | [.name, .id, .state, .owner]
      | @tsv
    ' 2>/dev/null)"
    if [[ -n "$out" ]]; then
      awk -F'\t' 'BEGIN{
        printf "%-40s %-36s %-10s %s\n","Name","AccountID","State","Owner"
      }{
        printf "%-40s %-36s %-10s %s\n",$1,$2,$3,$4
      }' <<<"$out"
      return 0
    fi
  fi

  # Fallback: parse tabular output (no JSON available)
  ibmcloud account list 2>/dev/null \
  | awk 'NR<=2{next} NF{print}' \
  | awk 'BEGIN{
      printf "%-40s %-36s %-10s %s\n","Name","AccountID","State","Owner"
    }{
      # split on 2+ spaces to keep single spaces inside the Name column
      n=split($0, a, /[[:space:]]{2,}/)
      name=a[1]; acct=a[2]; state=a[3]; owner=a[4]
      if (owner=="") owner="n/a"
      printf "%-40s %-36s %-10s %s\n", name, acct, state, owner
    }'
}

# ibmaccswap <sandbox|eposit|IMS_ID|/path/key.json>  [-s]
ibmaccswap() {
  local sel="${1:-}"; shift || true
  [[ -n "$sel" ]] || { echo "Usage: ibmaccswap <acct|keyfile> [-s]"; return 1; }
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

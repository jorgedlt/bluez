#!/usr/bin/env bash
# loopsha.sh — run a function or command across all accounts

mask(){ local s="$1"; local n=${#s}; ((n<=8)) && printf "%s" "$s" || printf "%s...%s" "${s:0:4}" "${s: -4}"; }
can_run(){ type -t "$1" >/dev/null 2>&1 || command -v "$1" >/dev/null 2>&1; }

loopsha() {
  _need ibmcloud || { echo "ibmcloud not found"; return 1; }
  _need jq || { echo "jq not found"; return 1; }

  local files=( "$HOME"/ibmcloud_key_*.json )
  local cmd="$1"; shift || true
  local args=("$@")
  local pass=0 fail=0

  [[ -n "$cmd" ]] || { echo "usage: loopsha <func-or-exec> [args...]"; return 1; }
  can_run "$cmd" || { echo "command not found: $cmd"; return 1; }

  for keyf in "${files[@]}"; do
    echo "===== $(basename "$keyf") ====="
    [[ -r "$keyf" ]] || { echo "MISSING $keyf"; ((fail++)); continue; }

    if ! ibmcloud login --apikey @"$keyf" -q; then
      echo "LOGIN FAILED"
      ((fail++)); continue
    fi

    local guid name
    read -r guid name < <(ibmcloud target --output json 2>/dev/null | jq -r '[.account.guid,.account.name] | @tsv')
    echo "ACTIVE -> ${name:-unknown} (GUID $(mask "$guid"))"

    if ! "$cmd" "${args[@]}"; then
      echo "COMMAND FAILED on $(basename "$keyf")"
    fi
    ((pass++))
  done

  echo "===== SUMMARY ====="
  echo "LOGINS: $pass  SKIPPED/FAILED: $fail"
  echo "Active session points to the last successful login."
}

loopsha_cmd() {
  _need ibmcloud || { echo "ibmcloud not found"; return 1; }
  _need jq || { echo "jq not found"; return 1; }

  [[ $# -ge 1 ]] || { echo "usage: loopsha_cmd '<command>'"; return 1; }
  local files=( "$HOME"/ibmcloud_key_*.json )
  local cmd="$1"

  for keyf in "${files[@]}"; do
    echo "===== $(basename "$keyf") ====="
    if ! ibmcloud login --apikey @"$keyf" -q; then
      echo "LOGIN FAILED"
      continue
    fi
    local guid name
    read -r guid name < <(ibmcloud target --output json 2>/dev/null | jq -r '[.account.guid,.account.name] | @tsv')
    echo "ACTIVE -> ${name:-unknown} (GUID $(mask "$guid"))"
    if ! bash -lc "$cmd"; then
      echo "COMMAND FAILED on $(basename "$keyf")"
    fi
  done
  echo "===== DONE ====="
}

#!/usr/bin/env bash
# loopsha.sh — run a function or command across all accounts

# Usage: loopsha <func-or-exec> [args...]
loopsha() {
  command -v ibmcloud >/dev/null || { echo "ibmcloud not found"; return 1; }
  local files=(
    "$HOME/ibmcloud_key_legacy-128.json"
    "$HOME/ibmcloud_key_sandbox-011.json"
    "$HOME/ibmcloud_key_DevAlpha-729.json"
    "$HOME/ibmcloud_key_DevBeta-651.json"
    "$HOME/ibmcloud_key_DevGamma-773.json"
  )
  local cmd="$1"; shift || true
  local args=("$@")
  local pass=0 fail=0

  mask(){ local s="$1"; local n=${#s}; ((n<=8)) && printf "%s\n" "$s" || printf "%s...%s\n" "${s:0:4}" "${s: -4}"; }
  can_run(){ type -t "$1" >/dev/null 2>&1 || command -v "$1" >/dev/null 2>&1; }

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
    read -r guid name < <(ibmcloud target --output JSON 2>/dev/null | jq -r '[.account.guid,.account.name] | @tsv')
    echo "ACTIVE -> ${name:-unknown} (GUID $(mask "$guid"))"

    "$cmd" "${args[@]}" || true
    ((pass++))
  done

  echo "===== SUMMARY ====="
  echo "LOGINS: $pass  SKIPPED/FAILED: $fail"
  echo "Active session points to the last successful login."
}

# Usage: loopsha_cmd "<ibmcloud pipeline as single string>"
loopsha_cmd() {
  command -v ibmcloud >/dev/null || { echo "ibmcloud not found"; return 1; }
  [[ $# -ge 1 ]] || { echo "usage: loopsha_cmd '<command>'"; return 1; }
  local files=(
    "$HOME/ibmcloud_key_legacy-128.json"
    "$HOME/ibmcloud_key_sandbox-011.json"
    "$HOME/ibmcloud_key_DevAlpha-729.json"
    "$HOME/ibmcloud_key_DevBeta-651.json"
    "$HOME/ibmcloud_key_DevGamma-773.json"
  )
  local cmd="$1"
  mask(){ local s="$1"; local n=${#s}; ((n<=8)) && printf "%s\n" "$s" || printf "%s...%s\n" "${s:0:4}" "${s: -4}"; }

  for keyf in "${files[@]}"; do
    echo "===== $(basename "$keyf") ====="
    if ! ibmcloud login --apikey @"$keyf" -q; then echo "LOGIN FAILED"; continue; fi
    local guid name
    read -r guid name < <(ibmcloud target --output JSON 2>/dev/null | jq -r '[.account.guid,.account.name] | @tsv')
    echo "ACTIVE -> ${name:-unknown} (GUID $(mask "$guid"))"
    bash -lc "$cmd" || true
  done
  echo "===== DONE ====="
}

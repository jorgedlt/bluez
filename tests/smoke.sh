#!/usr/bin/env bash
# tests/smoke.sh — unified smoke test for bluez IBM Cloud helpers

set -euo pipefail

# Repo root
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load helpers
# shellcheck source=/dev/null
source "$ROOT_DIR/tests/lib.sh"

# Load our functions if not already sourced
if ! command -v ibmwhoami >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/loader.sh"
fi

need ibmcloud
need jq

section "Smoke Test Start"
note "Repo: $ROOT_DIR"

section "Current Target"
ibmwhoami || true

section "Account List"
run ibmaccls

section "Swap Accounts"
run ibmaccswap sandbox
run ibmwhoami
run ibmaccswap epositbox
run ibmwhoami

section "Resource Group Lifecycle"
TMP_RG="demo-rg-$(date +%s)"
note "Creating RG: $TMP_RG"
run ibmrgmk "$TMP_RG" --target
sleep 2
note "Listing RGs (should include $TMP_RG)"
run ibmrgls
note "Deleting RG: $TMP_RG"
run ibmrgrm "$TMP_RG" --force
sleep 2
note "Final RG list"
run ibmrgls

section "Help System"
run ibmhelp cos

section "Smoke Test Complete"

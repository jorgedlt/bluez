#!/usr/bin/env bash
# tests/smoke.sh - quick “does it still work?” check for core IBM Cloud helpers

set -euo pipefail

# --- tiny helpers (inline) ----------------------------------------------------
section(){ printf "\n== %s ==\n" "$*"; }
note(){ printf -- "-- %s\n" "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
run(){ printf "\n$ %s\n" "$*"; "$@" || true; }

# --- repo root & loader -------------------------------------------------------
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load loader.sh if our functions aren't present
if ! command -v ibmwhoami >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/loader.sh"
fi

# Prefer your existing rich test library if present (non-essential)
if [[ -f "$ROOT_DIR/tests/lib.sh" ]]; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/tests/lib.sh"
fi

need jq
need ibmcloud

echo "IBM Cloud Smoke Test"
echo "Using repo: $ROOT_DIR"

# Show current target
ibmwhoami

# -----------------------------------------------------------------------------
# Accounts / login checks
# -----------------------------------------------------------------------------
section "Accounts / Login"

run ibmaccls
run ibmwhoami

echo "Swapping to SandboxAccnt (by name)"
run ibmaccswap SandboxAccnt

echo "Swapping back (by GUID)"
run ibmaccswap 62794a08a0e5417d9e5b18a18aba3c01

# -----------------------------------------------------------------------------
# IAM Users (truncated check)
# -----------------------------------------------------------------------------
section "IAM Users (truncated)"
if command -v ibmuserls >/dev/null 2>&1; then
  run ibmuserls | head -5
else
  echo "(ibmuserls not found)"
fi

# -----------------------------------------------------------------------------
# Cloud Object Storage buckets
# -----------------------------------------------------------------------------
section "Cloud Object Storage buckets"

if command -v ibmcosls >/dev/null 2>&1; then
  run ibmcosls
  echo "Expect failure/empty on bogus bucket"
  bogus_out="$(ibmcosls not-a-real-bucket 2>/dev/null || true)"
  if [[ -z "$bogus_out" ]]; then
    echo "Bogus bucket check OK (empty result)"
  else
    echo "Unexpected non-empty result for bogus bucket!"
  fi
else
  echo "(ibmcosls not found)"
fi

# -----------------------------------------------------------------------------
# Resource Group lifecycle
# -----------------------------------------------------------------------------
TMP_RG="demo-rg-$(date +%s)"

section "Creating temporary Resource Group: $TMP_RG"
run ibmrgmk "$TMP_RG" --target
sleep 2

section "Listing RGs (expect to see $TMP_RG)"
run ibmrgls

section "Showing details for: $TMP_RG"
ibmrgshow "$TMP_RG" \
  | jq -r '.[0]? // {} |
           "Name: \(.name // "unknown")\nID: \(.id // "unknown")\nState: \(.state // "unknown")\n"'

section "Cleaning up temporary Resource Group: $TMP_RG"
run ibmrgrm "$TMP_RG" --force
sleep 2

section "Final RG list (should NOT include $TMP_RG)"
run ibmrgls

# -----------------------------------------------------------------------------
# Help system
# -----------------------------------------------------------------------------
section "Help system"
run ibmhelp cos

echo
echo "Smoke test completed."

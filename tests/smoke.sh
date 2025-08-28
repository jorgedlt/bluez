#!/usr/bin/env bash
# tests/smoke.sh - quick “does it still work?” check for core IBM Cloud helpers

set -euo pipefail

# --- tiny helpers (inline) ----------------------------------------------------
section(){ printf "\n== %s ==\n" "$*"; }
note(){ printf -- "-- %s\n" "$*"; }
need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
run(){ printf "\n$ %s\n" "$*"; "$@"; }

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
# Create a temporary Resource Group and verify basic flows
# -----------------------------------------------------------------------------
TMP_RG="demo-rg-$(date +%s)"

section "Creating temporary Resource Group: $TMP_RG"
# --target: after creation, set target to the new RG so subsequent commands work
run ibmrgmk "$TMP_RG" --target

# Let the control plane settle briefly
sleep 2

section "Listing RGs (expect to see $TMP_RG)"
run ibmrgls

section "Showing details for: $TMP_RG"
# Note: ibmrgshow returns a JSON ARRAY (single element) -> index [0]
# Use [0]? so we don't crash if nothing comes back
ibmrgshow "$TMP_RG" \
  | jq -r '.[0]? // {} |
           "Name: \(.name // "unknown")\nID: \(.id // "unknown")\nState: \(.state // "unknown")\n"'

# -----------------------------------------------------------------------------
# Clean up: remove the temporary RG and confirm it’s gone
# -----------------------------------------------------------------------------
section "Cleaning up temporary Resource Group: $TMP_RG"
run ibmrgrm "$TMP_RG" --force

sleep 2

section "Final RG list (should NOT include $TMP_RG)"
run ibmrgls

echo
echo "Smoke test completed."

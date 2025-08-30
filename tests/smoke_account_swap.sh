#!/usr/bin/env bash
# Quick smoke test for ibmaccswap without modifying source code.
# Verifies swapping between SandboxAccnt and EpositBox and checks the active account GUID.

set -euo pipefail

# Minimal output helpers
ok()   { printf '\033[32m✔ %s\033[0m\n' "$*"; }
err()  { printf '\033[31m✘ %s\033[0m\n' "$*" >&2; }
note() { printf '\033[36m%s\033[0m\n' "$*"; }

need() { command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }; }

# Resolve repo root
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load loader if needed
if ! command -v ibmwhoami >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/loader.sh"
fi

need ibmcloud
need jq

# Expected GUIDs, from your init.sh aliases and earlier output
GUID_SANDBOX="62794a08a0e5417d9e5b18a18aba3c01"
GUID_EPOSIT="0bc27b84373c4d88b40c98dbc3690c21"

# Optionally pin a region up-front to avoid any region prompts
REGION="${IBMC_REGION:-us-south}"
ibmcloud target -r "$REGION" >/dev/null 2>&1 || true

# Ensure keyfiles are readable so ibmaccswap will succeed
: "${IBMC_KEYFILE_SANDBOX:=$HOME/ibmcloud_api_key_sandbox.json}"
: "${IBMC_KEYFILE_EPOSIT:=$HOME/ibmcloud_api_key.json}"

[[ -r "$IBMC_KEYFILE_SANDBOX" ]] || { err "Key not readable: $IBMC_KEYFILE_SANDBOX"; exit 1; }
[[ -r "$IBMC_KEYFILE_EPOSIT"  ]] || { err "Key not readable: $IBMC_KEYFILE_EPOSIT";  exit 1; }

# Helpers
current_guid() {
  ibmcloud target --output json 2>/dev/null | jq -r '.account.guid // empty'
}

swap_and_assert() {
  local selector="$1" expected_guid="$2" label="$3"
  note "Swapping to $label ($selector)"
  ibmaccswap "$selector" >/dev/null
  # give the CLI a breath
  sleep 1
  local got
  got="$(current_guid)"
  if [[ "$got" == "$expected_guid" ]]; then
    ok "Active account GUID is $got (expected $expected_guid) [$label]"
  else
    err "Active account GUID is $got, expected $expected_guid [$label]"
    return 1
  fi
}

# Show starting point
note "Starting target:"
ibmwhoami || true

# 1) Swap to Sandbox via alias
swap_and_assert "sandbox"  "$GUID_SANDBOX" "SandboxAccnt"

# 2) Swap to Eposit via alias
swap_and_assert "eposit"   "$GUID_EPOSIT"  "EpositBox"

# 3) Swap back to Sandbox via GUID
swap_and_assert "$GUID_SANDBOX" "$GUID_SANDBOX" "SandboxAccnt (via GUID)"

note "Final target:"
ibmwhoami || true

ok "Account swap smoke test completed"

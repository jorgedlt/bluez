#!/usr/bin/env bash
# tests/smoke_whoami_login.sh - smoke test for ibmlogin and ibmwhoami endpoint parsing

set -euo pipefail

if [[ -z "${IBMC_APIKEY:-}" ]]; then
  echo "[SKIP] IBMC_APIKEY is not set. Skipping smoke_whoami_login test."
  exit 0
fi

if [[ -z "${IBMC_REGION:-}" ]]; then
  echo "[SKIP] IBMC_REGION is not set. Skipping smoke_whoami_login test."
  exit 0
fi

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load loader.sh if our functions aren't present
if ! command -v ibmlogin >/dev/null 2>&1; then
  # shellcheck source=/dev/null
  source "$ROOT_DIR/loader.sh"
fi

need(){ command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }
need jq
need ibmcloud

section(){ printf "\n== %s ==\n" "$*"; }
note(){ printf -- "-- %s\n" "$*"; }

section "Login"
ibmlogin --no-region && echo "[FAIL] ibmlogin should fail without region" && exit 1 || echo "[OK] ibmlogin fails without region as expected"
ibmlogin "$IBMC_APIKEY" "$IBMC_REGION"

section "ibmwhoami output"
whoami_out="$(ibmwhoami)"
echo "$whoami_out"

endpoint="$(echo "$whoami_out" | grep -E '^Endpoint:' | awk '{print $2}')"
if [[ "$endpoint" == *://* ]]; then
  echo "[OK] Endpoint contains :// as expected"
else
  echo "[FAIL] Endpoint does not contain ://"
  exit 1
fi

exit 0

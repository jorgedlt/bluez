#!/usr/bin/env bash
# Login to IMS 2617128 (EpositBox) using $HOME/ibmcloud_api_key.json

set -euo pipefail

REGION="${1:-us-south}"         # allow override: ./ibm-login-128.sh eu-de
KEYFILE="${HOME}/ibmcloud_api_key.json"

need() { command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1" >&2; exit 1; }; }

need jq
need ibmcloud

[[ -r "$KEYFILE" ]] || { echo "Key file not readable: $KEYFILE" >&2; exit 1; }

export TF_VAR_ibmcloud_api_key
TF_VAR_ibmcloud_api_key="$(jq -r '.apikey // empty' < "$KEYFILE")"
[[ -n "$TF_VAR_ibmcloud_api_key" ]] || { echo "No .apikey in $KEYFILE" >&2; exit 1; }

ibmcloud logout >/dev/null 2>&1 || true
ibmcloud login -a https://cloud.ibm.com --apikey "$TF_VAR_ibmcloud_api_key" -r "$REGION" -q
ibmcloud target -r "$REGION" >/dev/null

# Optional RG target via env IBMC_RG, default none
if [[ -n "${IBMC_RG:-}" ]]; then
  ibmcloud target -g "$IBMC_RG" >/dev/null || true
fi

# Show summary
ibmcloud target

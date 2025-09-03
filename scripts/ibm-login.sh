#!/usr/bin/env bash
# Unified login: ./ibm-login.sh 128 [region]   or   ./ibm-login.sh 011 [region]
# Also accepts aliases: eposit, sandbox
set -euo pipefail

usage() { echo "Usage: $0 <128|011|eposit|sandbox> [region]"; exit 2; }

[[ $# -ge 1 ]] || usage
SEL="$1"
REGION="${2:-us-south}"

case "$SEL" in
  128|eposit)  KEYFILE="${HOME}/ibmcloud_api_key.json" ;;
  011|sandbox) KEYFILE="${HOME}/ibmcloud_api_key_sandbox.json" ;;
  *) usage ;;
esac

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

if [[ -n "${IBMC_RG:-}" ]]; then
  ibmcloud target -g "$IBMC_RG" >/dev/null || true
fi

ibmcloud target

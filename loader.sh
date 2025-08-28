#!/usr/bin/env bash
# loader.sh — main bootstrapper for the IBM Cloud helper toolkit.
# - Idempotent
# - Resolves repo root and loads init + all functions/*.sh in lexicographic order
# - Fails fast if required deps/env are missing

# Guard against double-sourcing
if [[ -n "${__IBMC_TOOLKIT_LOADED:-}" ]]; then
  return 0
fi
export __IBMC_TOOLKIT_LOADED=1

# Keep strict mode here (don’t force it inside sourced libs)
set -Eeuo pipefail

# Resolve repo root (directory where this loader lives)
__IBMC_TOOLKIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source init first
if [[ ! -f "${__IBMC_TOOLKIT_ROOT}/init.sh" ]]; then
  echo "[loader] ERROR: init.sh not found next to loader.sh" >&2
  return 1
fi
# shellcheck source=init.sh
source "${__IBMC_TOOLKIT_ROOT}/init.sh"

# Source all function modules in predictable order (lexicographic by filename)
shopt -s nullglob
__mods=( "${__IBMC_TOOLKIT_ROOT}"/functions/*.sh )
IFS=$'\n' __mods=( $(printf "%s\n" "${__mods[@]}" | sort) ); unset IFS

for __m in "${__mods[@]}"; do
  # shellcheck disable=SC1090
  source "${__m}"
done
unset __mods __m

# Quick success note (quiet if not interactive)
if [[ -t 1 ]]; then
  echo "[loader] IBM Cloud toolkit loaded from ${__IBMC_TOOLKIT_ROOT}"
fi

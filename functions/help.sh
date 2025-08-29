#!/usr/bin/env bash
# help.sh — dynamic help for all loaded modules
# - Scans functions/*.sh for lines starting with "# Usage:".
# - If a function lacks a Usage line but has a nearby comment header, show its name.
# - Supports optional filtering: `ibmhelp <keyword>`.

ibmhelp() {
  local root="${BLUEZ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  local filter="${1:-}"

  shopt -s nullglob
  local files=("$root/functions/"*.sh)

  local leftw=28
  local any_match=0     # tracks whether ANY file printed a match

  for f in "${files[@]}"; do
    local base; base="$(basename "$f")"

    # 1) Collect explicit Usage lines
    local -a usages=()
    while IFS= read -r line; do
      # strip leading "# Usage:" (allow optional extra spaces)
      line="${line#\#}"
      line="${line# }"
      line="${line#Usage: }"
      [[ -z "$filter" || "$line" == *"$filter"* ]] && usages+=("$line")
    done < <(grep -nE '^[[:space:]]*#[: ]+Usage:' "$f" 2>/dev/null || true)

    # 2) Fallback: function names that have a comment just above
    # (comment within 3 lines before "name() {")
    local -a fallbacks=()
    while IFS= read -r fn; do
      # Skip fallback if already covered by an explicit Usage line
      local dup=0
      for L in "${usages[@]}"; do
        [[ "$L" == "$fn"* ]] && { dup=1; break; }
      done
      (( dup )) && continue
      [[ -z "$filter" || "$fn" == *"$filter"* ]] && fallbacks+=("$fn")
    done < <(awk '
      /^[[:space:]]*#/ { last_comment=NR; next }
      /^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/ {
        if (last_comment && NR-last_comment<=3) {
          name=$1; sub(/\(.*/,"",name); print name
        }
        last_comment=0
      }
    ' "$f" | sort -u)

    # If nothing to show for this file, continue
    if ((${#usages[@]}==0 && ${#fallbacks[@]}==0)); then
      continue
    fi

    any_match=1

    # Pretty file header: first meaningful comment line, else filename
    local hdr
    hdr="$(awk '
      NR==1{next}
      /^#[[:space:]]*[-A-Za-z0-9]/ { sub(/^#[[:space:]]*/,""); print; exit }
    ' "$f")"
    [[ -z "$hdr" ]] && hdr="$base"

    printf "%s — %s\n" "$base" "$hdr"

    # Print Usage lines first
    for L in "${usages[@]}"; do
      local cmd="${L%% *}"
      local args=""
      [[ "$cmd" == "$L" ]] || args="${L#"$cmd"}"
      printf "  %-${leftw}s %s\n" "$cmd" "$args"
    done

    # Then fallbacks
    for fn in "${fallbacks[@]}"; do
      printf "  %-${leftw}s %s\n" "$fn" ""
    done

    echo
  done

  # If a filter was provided and nothing matched, say so — without recursion.
  if [[ -n "$filter" && $any_match -eq 0 ]]; then
    printf '(no matching commands/usages for filter: "%s")\n' "$filter"
  fi
}

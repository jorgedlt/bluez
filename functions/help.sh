#!/usr/bin/env bash
# help.sh — dynamic help for all loaded modules
# - Scans functions/*.sh for lines starting with "# Usage:" and prints them.
# - Accepts optional filtering:  ibmhelp <keyword>
# - Pretty, colored, de-duplicated output.

ibmhelp() {
  local root="${BLUEZ_ROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  local filter="${1:-}"
  local -i any=0

  # Colors
  local _bold _reset _cyan
  _bold="$(tput bold 2>/dev/null || true)"
  _reset="$(tput sgr0 2>/dev/null || true)"
  _cyan="$(tput setaf 6 2>/dev/null || true)"

  # resolve files once
  shopt -s nullglob
  local files=("$root"/functions/*.sh)
  shopt -u nullglob

  # seen set to avoid duplicate Usage lines (across files)
  declare -A _seen

  # helper: trim leading/trailing spaces
  _trim() { sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//' ; }

  # helper: clean a "NN:# Usage: ..." line -> "Usage: ..."
  _clean_usage() {
    sed -E 's/^[[:space:]]*[0-9]+:[[:space:]]*#?[[:space:]]*Usage:[[:space:]]*/Usage: /; s/^[[:space:]]*#?[[:space:]]*Usage:[[:space:]]*/Usage: /' \
    | _trim
  }

  # helper: first descriptive comment line near top (not a Usage)
  _header_of() {
    awk '
      NR<=10 && $0 ~ /^#[[:space:]]+/ && $0 !~ /#[[:space:]]*Usage:/ {
        sub(/^#[[:space:]]*/, "", $0); print; exit
      }' "$1"
  }

  # helper: cyan rule
  _rule() { printf "%s%s%s\n" "${_cyan}" "─%.0s" "${_reset}" | head -c 90; echo; }

  # Iterate files in name-sorted order for stable output
  IFS=$'\n' files=($(printf "%s\n" "${files[@]}" | sort)); unset IFS

  for f in "${files[@]}"; do
    local base; base="$(basename "$f")"

    # collect all explicit Usage lines from the file
    local usages; usages="$(grep -nE '^[[:space:]]*#*[[:space:]]*Usage:' "$f" 2>/dev/null | _clean_usage | awk 'NF')"

    # optional filter: match file name, header text, or any usage line
    local hdr; hdr="$(_header_of "$f")"
    local include_file=1
    if [[ -n "$filter" ]]; then
      include_file=0
      # case-insensitive filter
      if echo "$base" | grep -iq -- "$filter"; then include_file=1; fi
      if [[ $include_file -eq 0 && -n "$hdr" ]] && echo "$hdr" | grep -iq -- "$filter"; then include_file=1; fi
      if [[ $include_file -eq 0 && -n "$usages" ]] && echo "$usages" | grep -iq -- "$filter"; then include_file=1; fi
    fi
    [[ $include_file -eq 1 ]] || continue

    # nothing to show? (no usages and no header match) skip
    if [[ -z "$usages" ]]; then
      # still show a section if file matched the filter (by its name/header) to help discovery
      if [[ -n "$filter" ]]; then
        echo
        printf "%s%s%s — %s\n" "${_bold}${_cyan}" "${base}" "${_reset}" "${hdr:-"(no description)"}"
        _rule
        printf "  %s\n" "(No Usage lines found in this module yet.)"
        any=1
      fi
      continue
    fi

    # print section header
    echo
    printf "%s%s%s — %s\n" "${_bold}${_cyan}" "${base}" "${_reset}" "${hdr:-"(no description)"}"
    _rule

    # print each Usage once
    local printed=0
    while IFS= read -r u; do
      [[ -n "$u" ]] || continue

      # optional filter at the line level
      if [[ -n "$filter" ]] && ! echo "$u" | grep -iq -- "$filter"; then
        # still allow showing if file/header matched; we already decided to include the file,
        # but we want the lines to reflect the filter. So skip non-matching lines when filter is present.
        continue
      fi

      if [[ -z "${_seen[$u]+x}" ]]; then
        _seen["$u"]=1
        printf "  %s\n" "$u"
        printed=1
      fi
    done <<< "$usages"

    # if filtering eliminated all usages for this file, show a small note once
    if [[ $printed -eq 0 && -n "$filter" ]]; then
      printf "  %s\n" "(No matching commands/usages in this module for filter: \"$filter\")"
    fi

    any=1
  done

  if [[ $any -eq 0 ]]; then
    printf "No commands matched filter: %s\n" "${filter:-(none)}"
  fi
}

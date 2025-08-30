#!/usr/bin/env bash
# functions/help.sh — ibmhelp: IBM Cloud help system wrapper

ibmhelp() {
  ibmcloud help "$@"
}
#!/usr/bin/env bash
# help.sh, dynamic help for loaded modules

ibmhelp() {
  local root="${BLUEZ_ROOT:-"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"}"
  local filter="${1:-}"
  local -i any=0

  local _bold _reset _cyan
  _bold="$(tput bold 2>/dev/null || true)"
  _reset="$(tput sgr0 2>/dev/null || true)"
  _cyan="$(tput setaf 6 2>/dev/null || true)"

  shopt -s nullglob
  local files=("$root"/functions/*.sh)
  shopt -u nullglob

  declare -A _seen

  _trim() { sed -e 's/^[[:space:]]\+//' -e 's/[[:space:]]\+$//' ; }

  _clean_usage() {
    sed -E 's/^[[:space:]]*[0-9]+:[[:space:]]*#?[[:space:]]*Usage:[[:space:]]*/Usage: /; s/^[[:space:]]*#?[[:space:]]*Usage:[[:space:]]*/Usage: /' \
    | _trim
  }

  _header_of() {
    awk '
      NR<=10 && $0 ~ /^#[[:space:]]+/ && $0 !~ /#[[:space:]]*Usage:/ {
        sub(/^#[[:space:]]*/, "", $0); print; exit
      }' "$1"
  }

  _rule() {
    local line
    line="$(printf '%*s' 90 '')"
    line="${line// /-}"
    printf "%s%s%s\n" "${_cyan}" "$line" "${_reset}"
  }

  IFS=$'\n' files=($(printf "%s\n" "${files[@]}" | sort)); unset IFS

  for f in "${files[@]}"; do
    local base; base="$(basename "$f")"
    local usages; usages="$(grep -nE '^[[:space:]]*#*[[:space:]]*Usage:' "$f" 2>/dev/null | _clean_usage | awk 'NF')"
    local hdr; hdr="$(_header_of "$f")"

    local include_file=1 file_matched=0
    if [[ -n "$filter" ]]; then
      include_file=0
      if echo "$base" | grep -iq -- "$filter"; then include_file=1; file_matched=1; fi
      if [[ $include_file -eq 0 && -n "$hdr" ]] && echo "$hdr" | grep -iq -- "$filter"; then include_file=1; file_matched=1; fi
      if [[ $include_file -eq 0 && -n "$usages" ]] && echo "$usages" | grep -iq -- "$filter"; then include_file=1; fi
    fi
    [[ $include_file -eq 1 ]] || continue

    if [[ -z "$usages" ]]; then
      if [[ -n "$filter" ]]; then
        echo
        printf "%s%s%s — %s\n" "${_bold}${_cyan}" "${base}" "${_reset}" "${hdr:-"(no description)"}"
        _rule
        printf "  %s\n" "(No Usage lines found in this module yet.)"
        any=1
      fi
      continue
    fi

    echo
    printf "%s%s%s — %s\n" "${_bold}${_cyan}" "${base}" "${_reset}" "${hdr:-"(no description)"}"
    _rule

    local printed=0
    while IFS= read -r u; do
      [[ -n "$u" ]] || continue
      if [[ -n "$filter" && $file_matched -eq 0 ]] && ! echo "$u" | grep -iq -- "$filter"; then
        continue
      fi
      if [[ -z "${_seen[$u]+x}" ]]; then
        _seen["$u"]=1
        printf "  %s\n" "$u"
        printed=1
      fi
    done <<< "$usages"

    if [[ $printed -eq 0 && -n "$filter" ]]; then
      printf "  %s\n" "(No matching commands/usages in this module for filter: \"$filter\")"
    fi

    any=1
  done

  if [[ $any -eq 0 ]]; then
    printf "No commands matched filter: %s\n" "${filter:-(none)}"
  fi
}

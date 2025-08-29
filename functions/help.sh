#!/usr/bin/env bash
# help.sh — dynamic help that scans all modules for `# Usage:` lines

# ibmhelp [keyword]
# - No args: prints all modules with their commands/usages
# - With a keyword: case-insensitive filter across module titles, function
#   names, and usage text (e.g., `ibmhelp rg`, `ibmhelp toolchain`).
ibmhelp() {
  local root="${BLUEZ_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  local dir="${root}/functions"
  local kw="${1:-}" has_kw=0
  [[ -n "$kw" ]] && has_kw=1

  if [[ ! -d "$dir" ]]; then
    echo "ibmhelp: functions directory not found: ${dir}" >&2
    return 1
  fi

  # Find module files (non-recursive), sorted by name
  local files=()
  while IFS= read -r -d '' f; do files+=("$f"); done < <(find "$dir" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
  [[ ${#files[@]} -gt 0 ]] || { echo "ibmhelp: no modules found in ${dir}" >&2; return 1; }

  # Pretty colors (fallback if no color support)
  local BOLD=$'\033[1m' CYAN=$'\033[36m' RESET=$'\033[0m'
  [[ -t 1 ]] || { BOLD=""; CYAN=""; RESET=""; }

  local printed_any=0

  for f in "${files[@]}"; do
    # Extract a nice module title from the top comment like:
    #   "# <name>.sh — description"
    # Fallback to filename if no header line is found.
    local title
    title="$(awk '
      NR<=25 && /^# / {
        sub(/^# /,"",$0)
        if ($0 ~ /^.*—.*$/) { print $0; exit }
      }
    ' "$f")"
    [[ -n "$title" ]] || title="$(basename "$f")"

    # Gather all `# Usage:` lines and try to pair with the next function name if present
    # We’ll output "<function>: <usage>" or just "<usage>" if function can’t be found.
    local block
    block="$(awk '
      function ltrim(s){ sub(/^[[:space:]]+/,"",s); return s }
      function rtrim(s){ sub(/[[:space:]]+$/,"",s); return s }
      function trim(s){ return rtrim(ltrim(s)) }

      # capture function names: foo() {
      /^[a-zA-Z_][a-zA-Z0-9_]*\(\)[[:space:]]*{/ {
        fn=$0; sub(/\(\).*/,"",fn); lastfn=fn
      }

      # capture usage lines: "# Usage: ...."
      /^#[[:space:]]*[Uu]sage:/ {
        u=$0; sub(/^#[[:space:]]*[Uu]sage:[[:space:]]*/,"",u)
        usage = trim(u)
        # emit "function\tusage" (function may be empty if not seen yet)
        if (lastfn != "") {
          print lastfn "\t" usage
        } else {
          print "\t" usage
        }
      }
    ' "$f")"

    # If the module has no Usage lines, skip it (unless filtering would still match title).
    if [[ -z "$block" ]]; then
      if (( has_kw )); then
        # Only show module if the title matches the filter.
        if grep -qi -- "$kw" <<<"$title"; then
          printf "%s%s%s\n" "$BOLD$CYAN" "$title" "$RESET"
          echo "  (no explicit Usage: lines found)"
          echo
          printed_any=1
        fi
      fi
      continue
    fi

    # Apply keyword filtering over title, function names, and usage text.
    local filtered="$block"
    if (( has_kw )); then
      filtered="$(echo "$block" \
        | awk -v kw="$kw" -F'\t' '
            BEGIN{IGNORECASE=1}
            {
              fn=$1; u=$2
              if (index(fn,kw) || index(u,kw)) print $0
            }
          ' )"
      # If title matches but no lines matched, we’ll still print the title and note.
      if [[ -z "$filtered" ]] && grep -qi -- "$kw" <<<"$title"; then
        printf "%s%s%s\n" "$BOLD$CYAN" "$title" "$RESET"
        echo "  (no matching commands/usages for filter: \"$kw\")"
        echo
        printed_any=1
        continue
      fi
      [[ -n "$filtered" ]] || continue
    fi

    # Print the module and its usages
    printf "%s%s%s\n" "$BOLD$CYAN" "$title" "$RESET"
    echo "$filtered" \
      | while IFS=$'\t' read -r fn usage; do
          if [[ -n "$fn" ]]; then
            printf "  %-24s  %s\n" "${fn}:" "$usage"
          else
            printf "  %-24s  %s\n" "" "$usage"
          fi
        done
    echo
    printed_any=1
  done

  if (( ! printed_any )); then
    if (( has_kw )); then
      echo "ibmhelp: no results for \"$kw\""
    else
      echo "ibmhelp: nothing to show"
    fi
    return 1
  fi
}

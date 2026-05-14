#!/usr/bin/env bash
# ============================================================
# SCRIPT LAUNCHER - Dynamic menu from GitHub scripts.txt
# Usage: bash <(curl -s https://raw.githubusercontent.com/hosting3-ui/Scripts/main/run.sh)
# Add new scripts to scripts.txt - launcher auto-updates
# ============================================================

CYAN="\033[0;36m"; YELLOW="\033[1;33m"; GREEN="\033[0;32m"; RED="\033[0;31m"; DIM="\033[2m"; NC="\033[0m"
SCRIPTS_URL="https://raw.githubusercontent.com/hosting3-ui/Scripts/main/scripts.txt"

# Fetch the scripts list
RAW=$(curl -sf "${SCRIPTS_URL}?$(date +%s)" 2>/dev/null)
if [ -z "$RAW" ]; then
  echo -e "${RED}ERROR: Could not fetch scripts list from:${NC}"
  echo "  $SCRIPTS_URL"
  exit 1
fi

# Parse lines - expected format in scripts.txt:
#   Label | https://raw.githubusercontent.com/.../script.sh
# Lines starting with # are comments/section headers, blank lines are separators
declare -a LABELS
declare -a URLS
declare -a SECTION_LINES  # line numbers that are section headers

i=0
while IFS= read -r line; do
  # Skip blank lines
  [[ -z "$line" ]] && continue
  # Section headers start with #
  if [[ "$line" == \#* ]]; then
    LABELS[$i]="SECTION:${line:1}"  # strip the #
    URLS[$i]=""
    ((i++))
    continue
  fi
  # Normal entry: Label | URL
  label=$(echo "$line" | cut -d'|' -f1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  url=$(echo "$line"   | cut -d'|' -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  [ -z "$label" ] || [ -z "$url" ] && continue
  LABELS[$i]="$label"
  URLS[$i]="$url"
  ((i++))
done <<< "$RAW"

TOTAL=$i

while true; do
  clear
  echo -e "${CYAN}================================================================${NC}"
  echo -e "  SCRIPT LAUNCHER - $(hostname)"
  echo -e "  Source: scripts.txt | $(date +%H:%M)"
  echo -e "${CYAN}================================================================${NC}"
  echo

  # Print menu
  num=1
  declare -a INDEX_MAP  # maps menu number -> array index
  idx_map_i=0

  for (( j=0; j<TOTAL; j++ )); do
    entry="${LABELS[$j]}"
    if [[ "$entry" == SECTION:* ]]; then
      # Print section header
      section_name="${entry:8}"
      echo -e "  ${YELLOW}${section_name}${NC}"
    else
      printf "  ${GREEN}%2d)${NC} %s\n" "$num" "$entry"
      INDEX_MAP[$num]=$j
      ((num++))
    fi
  done

  LAST_NUM=$((num - 1))
  echo
  echo -e "  ${DIM}q) Quit${NC}"
  echo
  read -rp "Choose script (1-${LAST_NUM}): " CHOICE

  [[ "$CHOICE" == "q" || "$CHOICE" == "Q" ]] && echo "Bye!" && exit 0

  # Validate
  if ! [[ "$CHOICE" =~ ^[0-9]+$ ]] || [ -z "${INDEX_MAP[$CHOICE]}" ]; then
    echo -e "${RED}Invalid choice${NC}"
    sleep 1
    continue
  fi

  ARRAY_IDX=${INDEX_MAP[$CHOICE]}
  CHOSEN_LABEL="${LABELS[$ARRAY_IDX]}"
  CHOSEN_URL="${URLS[$ARRAY_IDX]}"

  clear
  echo -e "${CYAN}================================================================${NC}"
  echo -e "  Running: ${CHOSEN_LABEL}"
  echo -e "  URL: ${DIM}${CHOSEN_URL}${NC}"
  echo -e "${CYAN}================================================================${NC}"
  echo

  # Check if script needs an argument
  read -rp "Pass argument (e.g. IP, path, domain) or Enter to skip: " ARG

  echo
  if [ -n "$ARG" ]; then
    bash <(curl -sf "${CHOSEN_URL}?$(date +%s)") "$ARG"
  else
    bash <(curl -sf "${CHOSEN_URL}?$(date +%s)")
  fi

  echo
  echo -e "${GREEN}--- Script finished ---${NC}"
  read -rp "Press Enter to return to menu..."
done
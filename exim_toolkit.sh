#!/usr/bin/env bash
# ============================================================
# EXIM QUEUE TOOLKIT - Interactive
# Run as: root
# Compatible: cPanel/WHM, CloudLinux, AlmaLinux, CentOS
# ============================================================

[ "$(id -u)" -ne 0 ] && echo "ERROR: Must be run as root" && exit 1
command -v exim &>/dev/null || { echo "ERROR: exim not found"; exit 1; }

CYAN="\033[0;36m"; YELLOW="\033[1;33m"; GREEN="\033[0;32m"; RED="\033[0;31m"; NC="\033[0m"
EXIM_LOG="/var/log/exim_mainlog"
MAIL_LOG="/var/log/maillog"

print_header() {
  QUEUE=$(exim -bpc 2>/dev/null)
  FROZEN=$(exim -bp 2>/dev/null | grep -c frozen)
  echo -e "${CYAN}================================================================${NC}"
  echo -e " EXIM TOOLKIT - $(hostname) - $(date +%H:%M)"
  echo -e " Queue: ${QUEUE} | Frozen: ${FROZEN}"
  echo -e "${CYAN}================================================================${NC}"
}

clear
print_header

while true; do
  echo
  echo -e "${YELLOW}EXIM QUEUE OPERATIONS${NC}"
  echo "  --- Queue View ---"
  echo "  1)  Show full queue (last 50)"
  echo "  2)  Top senders in queue"
  echo "  3)  Show frozen messages"
  echo "  4)  Show queue for specific email/domain"
  echo "  --- Queue Delete ---"
  echo "  5)  Delete all frozen messages"
  echo "  6)  Delete queue by sender email/domain"
  echo "  7)  Delete queue by recipient email/domain"
  echo "  8)  Delete ALL messages in queue (with confirmation)"
  echo "  9)  Delete single message by ID"
  echo "  --- Log Analysis ---"
  echo " 10)  Grep mainlog by email/domain"
  echo " 11)  Grep mainlog by IP"
  echo " 12)  Top spam sources by cwd (script path)"
  echo " 13)  Top senders (last 1000 log lines)"
  echo " 14)  Auth failures (535 errors)"
  echo " 15)  Check SpamAssassin score for domain"
  echo "  --- Actions ---"
  echo " 16)  Attempt delivery of frozen messages"
  echo " 17)  Show message body by ID"
  echo " 18)  Refresh header (queue count)"
  echo "   q) Quit"
  echo
  read -rp "Choice: " CHOICE

  case "$CHOICE" in
    1)
      echo; exim -bp 2>/dev/null | head -50
      ;;
    2)
      echo
      echo "Top 20 senders in queue:"
      exim -bp 2>/dev/null | awk '/^[ 	]*[0-9]/{print $4}' | sort | uniq -c | sort -rn | head -20
      ;;
    3)
      echo; exim -bp 2>/dev/null | grep -A2 frozen | head -60
      ;;
    4)
      read -rp "Email or domain to search: " TERM
      exim -bp 2>/dev/null | grep -i "$TERM" | head -30
      ;;
    5)
      COUNT=$(exim -bp 2>/dev/null | grep -c frozen)
      read -rp "Delete $COUNT frozen messages? (y/n): " CONFIRM
      if [ "$CONFIRM" = "y" ]; then
        exim -bp 2>/dev/null | grep frozen | awk '{print $3}' | xargs -r exim -Mrm 2>/dev/null
        echo -e "${GREEN}Frozen messages deleted${NC}"
      fi
      ;;
    6)
      read -rp "Sender email or domain: " TERM
      IDS=$(exim -bp 2>/dev/null | grep -i "$TERM" | awk '{print $3}')
      COUNT=$(echo "$IDS" | grep -c .)
      [ -z "$IDS" ] && echo "No messages found" && continue
      read -rp "Delete $COUNT messages from '$TERM'? (y/n): " CONFIRM
      [ "$CONFIRM" = "y" ] && echo "$IDS" | xargs -r exim -Mrm 2>/dev/null && echo -e "${GREEN}Deleted${NC}"
      ;;
    7)
      read -rp "Recipient email or domain: " TERM
      IDS=$(exim -bp 2>/dev/null | awk '/'"$TERM"'/{print prev} {prev=$3}' | grep -v "^$")
      COUNT=$(echo "$IDS" | grep -c .)
      [ -z "$IDS" ] && echo "No messages found for recipient '$TERM'" && continue
      read -rp "Delete $COUNT messages to '$TERM'? (y/n): " CONFIRM
      [ "$CONFIRM" = "y" ] && echo "$IDS" | xargs -r exim -Mrm 2>/dev/null && echo -e "${GREEN}Deleted${NC}"
      ;;
    8)
      COUNT=$(exim -bpc 2>/dev/null)
      echo -e "${RED}WARNING: This will delete ALL $COUNT queued messages.${NC}"
      read -rp "Type DELETE to confirm: " CONFIRM
      if [ "$CONFIRM" = "DELETE" ]; then
        exim -bp 2>/dev/null | awk '/^[ 	]*[0-9]/{print $3}' | xargs -r exim -Mrm 2>/dev/null
        echo -e "${GREEN}Queue cleared${NC}"
      else
        echo "Cancelled"
      fi
      ;;
    9)
      read -rp "Message ID: " MID
      exim -Mrm "$MID" 2>/dev/null && echo -e "${GREEN}Deleted $MID${NC}"
      ;;
    10)
      read -rp "Email or domain: " TERM
      [ -f "$EXIM_LOG" ] && grep -i "$TERM" "$EXIM_LOG" | tail -40
      ;;
    11)
      read -rp "IP address: " IP
      [ -f "$EXIM_LOG" ] && grep "$IP" "$EXIM_LOG" | tail -40
      ;;
    12)
      echo "Top script paths sending mail (cwd in exim log):"
      [ -f "$EXIM_LOG" ] && grep "cwd=" "$EXIM_LOG" | grep -v "cwd=/var/spool"         | awk -F"cwd=" '{print $2}' | awk '{print $1}'         | sort | uniq -c | sort -rn | head -20         || echo "(exim_mainlog not found)"
      ;;
    13)
      echo "Top senders (last 1000 log lines):"
      [ -f "$EXIM_LOG" ] && tail -1000 "$EXIM_LOG" | grep " <= "         | grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'         | sort | uniq -c | sort -rn | head -20
      ;;
    14)
      echo "Top accounts with 535 auth failures:"
      [ -f "$EXIM_LOG" ] && grep "535 Incorrect" "$EXIM_LOG"         | awk -F"set_id=" '{print $2}' | awk '{print $1}'         | sort | uniq -c | sort -rn | head -20         || echo "(no 535 errors found or log not available)"
      ;;
    15)
      read -rp "Domain: " DOM
      [ -f "$EXIM_LOG" ] && grep -i "$DOM" "$EXIM_LOG" | grep -i "X-Spam" | tail -20
      ;;
    16)
      echo "Attempting delivery of frozen messages..."
      exim -bp 2>/dev/null | grep frozen | awk '{print $3}' | xargs -r exim -M 2>/dev/null
      echo -e "${GREEN}Done${NC}"
      ;;
    17)
      read -rp "Message ID: " MID
      exim -Mvb "$MID" 2>/dev/null | head -60
      ;;
    18)
      print_header
      ;;
    q|Q) echo "Bye!"; break ;;
    *) echo -e "${RED}Invalid choice${NC}" ;;
  esac
done
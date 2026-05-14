#!/usr/bin/env bash
# ============================================================
# DISK TOOLKIT - Interactive disk analysis and cleanup
# Compatible: CloudLinux, AlmaLinux, CentOS, cPanel
# Run as root for full access, or as cPanel user for home dir
# ============================================================

CYAN="\033[0;36m"; YELLOW="\033[1;33m"; GREEN="\033[0;32m"; RED="\033[0;31m"; DIM="\033[2m"; NC="\033[0m"

IS_ROOT=false
[ "$(id -u)" -eq 0 ] && IS_ROOT=true

clear
echo -e "${CYAN}================================================================${NC}"
echo -e " DISK TOOLKIT - $(hostname) - $(date +%H:%M)"
echo -e " User: $(whoami)"
df -h / 2>/dev/null | tail -1 | awk '{printf " Root disk: %s used of %s (%s free)\n", $3, $2, $4}'
echo -e "${CYAN}================================================================${NC}"

while true; do
  echo
  echo -e "${YELLOW}DISK OPERATIONS${NC}"
  echo "  --- Analysis ---"
  echo "  1)  Disk usage overview (all mounts)"
  echo "  2)  Inode usage overview"
  echo "  3)  Top 20 largest directories (from chosen path)"
  echo "  4)  Top 20 largest files (from chosen path)"
  echo "  5)  Find files larger than X MB"
  echo "  6)  Find large error logs (>20MB)"
  if $IS_ROOT; then
    echo "  7)  Top disk usage per cPanel account"
    echo "  8)  Top inode usage per cPanel account"
  else
    echo -e "  ${DIM}7)  Top disk usage per cPanel account (root only)${NC}"
    echo -e "  ${DIM}8)  Top inode usage per cPanel account (root only)${NC}"
  fi
  echo "  --- Cleanup ---"
  echo "  9)  Find old backup files (.sql, .sql.gz, .tar.gz, .zip older than X days)"
  echo " 10)  Truncate large error logs (>20MB)"
  echo " 11)  Clear all wp-content/cache folders under /home"
  echo " 12)  Clear PHP session files older than 24h"
  echo " 13)  Find and remove uncompressed .sql dumps in /home"
  echo "  --- Files ---"
  echo " 14)  Find recently modified files (last 24h)"
  echo " 15)  Find recently modified files (last 7 days)"
  echo " 16)  Find world-writable files (security risk)"
  echo "   q) Quit"
  echo
  read -rp "Choice: " CHOICE

  case "$CHOICE" in
    1)
      echo; df -hT 2>/dev/null
      ;;
    2)
      echo; df -i 2>/dev/null
      ;;
    3)
      read -rp "Directory (default: $(pwd)): " DIR
      DIR="${DIR:-.}"
      echo "Scanning $DIR ..."
      du -h --max-depth=2 "$DIR" 2>/dev/null | sort -hr | head -20
      ;;
    4)
      read -rp "Directory (default: $(pwd)): " DIR
      DIR="${DIR:-.}"
      echo "Scanning $DIR ..."
      find "$DIR" -type f -printf '%s %p\n' 2>/dev/null | sort -rn | head -20 | \
        awk '{printf "%-10s %s\n", int($1/1024/1024)"MB", $2}'
      ;;
    5)
      read -rp "Minimum size in MB (e.g. 200): " SIZE
      read -rp "Directory (default: $(pwd)): " DIR
      DIR="${DIR:-.}"
      echo "Files larger than ${SIZE}MB in $DIR ..."
      find "$DIR" -type f -size "+${SIZE}M" -printf '%s %p\n' 2>/dev/null | \
        sort -rn | awk '{printf "%-10s %s\n", int($1/1024/1024)"MB", $2}' | head -30
      ;;
    6)
      echo "Finding error logs larger than 20MB ..."
      find /home /usr/local/apache /var/log -type f -name "error_log" -size +20M \
        -printf '%s %p\n' 2>/dev/null | sort -rn | \
        awk '{printf "%-10s %s\n", int($1/1024/1024)"MB", $2}' | head -20
      ;;
    7)
      if ! $IS_ROOT; then echo -e "${RED}Root required${NC}"; continue; fi
      echo "Top 20 cPanel accounts by disk usage:"
      for user in $(ls /var/cpanel/users/ 2>/dev/null); do
        du -sh "/home/$user" 2>/dev/null | awk -v u="$user" '{print $1, u}'
      done | sort -hr | head -20 | awk '{printf "%-10s %s\n", $1, $2}'
      ;;
    8)
      if ! $IS_ROOT; then echo -e "${RED}Root required${NC}"; continue; fi
      echo "Top 20 cPanel accounts by inode usage:"
      for user in $(ls /var/cpanel/users/ 2>/dev/null); do
        count=$(find "/home/$user" 2>/dev/null | wc -l)
        echo "$count $user"
      done | sort -rn | head -20 | awk '{printf "%-10s %s\n", $1, $2}'
      ;;
    9)
      read -rp "Older than how many days (e.g. 30): " DAYS
      read -rp "Search directory (default: /home): " DIR
      DIR="${DIR:-/home}"
      echo "Finding backup files older than ${DAYS} days in $DIR ..."
      find "$DIR" -type f \( -name "*.sql.gz" -o -name "*.sql" -o -name "*.tar.gz" -o -name "*.zip" \) \
        -mtime "+${DAYS}" -printf '%s %p\n' 2>/dev/null | sort -rn | \
        awk '{printf "%-10s %s\n", int($1/1024/1024)"MB", $2}' | head -30
      echo
      read -rp "Delete all of the above? (y/n): " CONFIRM
      if [ "$CONFIRM" = "y" ]; then
        find "$DIR" -type f \( -name "*.sql.gz" -o -name "*.sql" -o -name "*.tar.gz" -o -name "*.zip" \) \
          -mtime "+${DAYS}" -delete 2>/dev/null
        echo -e "${GREEN}Deleted${NC}"
      fi
      ;;
    10)
      echo "Finding error logs > 20MB ..."
      LOGS=$(find /home /usr/local/apache /var/log -type f -name "error_log" -size +20M 2>/dev/null)
      [ -z "$LOGS" ] && echo "None found" && continue
      echo "$LOGS"
      read -rp "Truncate (empty) all of the above? (y/n): " CONFIRM
      if [ "$CONFIRM" = "y" ]; then
        echo "$LOGS" | while read -r f; do
          > "$f" && echo -e "${GREEN}Cleared: $f${NC}"
        done
      fi
      ;;
    11)
      echo "Finding wp-content/cache directories in /home ..."
      find /home -type d -name "cache" -path "*/wp-content/cache" 2>/dev/null | while read -r cachedir; do
        size=$(du -sh "$cachedir" 2>/dev/null | cut -f1)
        echo "  $size  $cachedir"
      done
      read -rp "Clear all of the above? (y/n): " CONFIRM
      if [ "$CONFIRM" = "y" ]; then
        find /home -type d -name "cache" -path "*/wp-content/cache" 2>/dev/null | while read -r cachedir; do
          rm -rf "${cachedir:?}"/* 2>/dev/null
          echo -e "${GREEN}Cleared: $cachedir${NC}"
        done
      fi
      ;;
    12)
      echo "PHP session directories:"
      PHP_SESS_DIRS=$(find /tmp /var/lib/php /home -maxdepth 4 -type d -name "session" 2>/dev/null | head -10)
      [ -z "$PHP_SESS_DIRS" ] && PHP_SESS_DIRS="/tmp"
      echo "$PHP_SESS_DIRS"
      read -rp "Delete session files older than 24h from above? (y/n): " CONFIRM
      if [ "$CONFIRM" = "y" ]; then
        echo "$PHP_SESS_DIRS" | while read -r sdir; do
          find "$sdir" -maxdepth 1 -name "sess_*" -mtime +1 -delete 2>/dev/null
          echo -e "${GREEN}Cleaned: $sdir${NC}"
        done
      fi
      ;;
    13)
      echo "Finding uncompressed .sql files in /home ..."
      find /home -type f -name "*.sql" -printf '%s %p\n' 2>/dev/null | sort -rn | \
        awk '{printf "%-10s %s\n", int($1/1024/1024)"MB", $2}' | head -20
      read -rp "Delete all uncompressed .sql files in /home? (y/n): " CONFIRM
      if [ "$CONFIRM" = "y" ]; then
        find /home -type f -name "*.sql" -delete 2>/dev/null
        echo -e "${GREEN}Done${NC}"
      fi
      ;;
    14)
      read -rp "Directory (default: $(pwd)): " DIR
      DIR="${DIR:-.}"
      echo "Files modified in last 24h in $DIR ..."
      find "$DIR" -type f -mtime -1 -printf '%TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort -r | head -30
      ;;
    15)
      read -rp "Directory (default: $(pwd)): " DIR
      DIR="${DIR:-.}"
      echo "Files modified in last 7 days in $DIR ..."
      find "$DIR" -type f -mtime -7 -printf '%TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort -r | head -40
      ;;
    16)
      read -rp "Directory (default: /home): " DIR
      DIR="${DIR:-/home}"
      echo "World-writable files in $DIR ..."
      find "$DIR" -type f -perm -o+w 2>/dev/null | grep -v "proc\|sys" | head -30
      ;;
    q|Q) echo "Bye!"; break ;;
    *) echo -e "${RED}Invalid choice${NC}" ;;
  esac
done

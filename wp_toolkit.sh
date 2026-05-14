#!/usr/bin/env bash
# ============================================================
# WORDPRESS TOOLKIT - Interactive
# Usage: bash wp_toolkit.sh (run from WordPress directory)
# Works as root OR as a cPanel user
# ============================================================

WP_PATH="."
ROOT_FLAG=""
[ "$(id -u)" -eq 0 ] && ROOT_FLAG="--allow-root"

# ---- Locate wp-cli ----
WP=""
if command -v wp &>/dev/null; then
  WP="wp"
else
  for p in /usr/local/bin/wp /usr/bin/wp /root/wp ~/wp-cli.phar; do
    [ -f "$p" ] && WP="php $p" && break
  done
fi

if [ -z "$WP" ]; then
  echo "wp-cli not found. Downloading to /tmp/wp-cli.phar ..."
  curl -s -o /tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
  chmod +x /tmp/wp-cli.phar
  WP="php /tmp/wp-cli.phar"
  CLEANUP_WP=true
fi

WP_CMD="$WP --path=$WP_PATH $ROOT_FLAG"

if [ ! -f "$WP_PATH/wp-config.php" ]; then
  echo "ERROR: No wp-config.php found in $(pwd)"
  echo "Please cd into the WordPress directory first."
  exit 1
fi

# ---- Colors ----
CYAN="\033[0;36m"; YELLOW="\033[1;33m"; GREEN="\033[0;32m"; RED="\033[0;31m"; NC="\033[0m"

# ---- Info Header ----
clear
echo -e "${CYAN}================================================================${NC}"
echo -e " WORDPRESS TOOLKIT"
echo -e " Path: $(pwd) | User: $(whoami)"
echo -e "${CYAN}================================================================${NC}"
echo "Version:   $($WP_CMD core version 2>/dev/null)"
echo "Site URL:  $($WP_CMD option get siteurl 2>/dev/null)"
echo "Home URL:  $($WP_CMD option get home 2>/dev/null)"
echo "DB Prefix: $($WP_CMD config get table_prefix 2>/dev/null)"
echo "PHP:       $(php -v 2>/dev/null | head -1 | cut -d" " -f1-2)"
echo -e "${CYAN}================================================================${NC}"

# ---- Menu ----
while true; do
  echo
  echo -e "${YELLOW}What would you like to do?${NC}"
  echo "  1) Verify core checksums"
  echo "  2) List plugins (show updates available)"
  echo "  3) Update all plugins"
  echo "  4) List admin users"
  echo "  5) Create admin user"
  echo "  6) Delete a user"
  echo "  7) Search and replace URL"
  echo "  8) Flush rewrite rules"
  echo "  9) Clear cache (W3TC / all cache folders)"
  echo " 10) Fix file/folder permissions"
  echo " 11) Clean Action Scheduler (3 months old)"
  echo " 12) Reinstall WordPress core"
  echo " 13) Remove immutable flags (chattr)"
  echo "  q) Quit"
  echo
  read -rp "Choice: " CHOICE

  case "$CHOICE" in
    1)
      echo
      $WP_CMD core verify-checksums 2>/dev/null \
        && echo -e "${GREEN}Core files OK${NC}" \
        || echo -e "${RED}CHECKSUM MISMATCH - files may be modified or hacked${NC}"
      ;;
    2)
      echo
      echo "--- All Plugins ---"
      $WP_CMD plugin list --format=table 2>/dev/null
      echo
      echo "--- Updates Available ---"
      $WP_CMD plugin list --update=available --format=table 2>/dev/null || echo "(none)"
      ;;
    3)
      echo
      read -rp "Update all plugins? (y/n): " CONFIRM
      [ "$CONFIRM" = "y" ] && $WP_CMD plugin update --all 2>/dev/null
      ;;
    4)
      echo
      $WP_CMD user list --role=administrator \
        --fields=ID,user_login,user_email,user_registered --format=table 2>/dev/null
      ;;
    5)
      echo
      read -rp "Username: " U_LOGIN
      read -rp "Email: " U_EMAIL
      read -rp "Password (leave blank to auto-generate): " U_PASS
      if [ -z "$U_PASS" ]; then
        $WP_CMD user create "$U_LOGIN" "$U_EMAIL" --role=administrator 2>/dev/null
      else
        $WP_CMD user create "$U_LOGIN" "$U_EMAIL" --role=administrator --user_pass="$U_PASS" 2>/dev/null
      fi
      ;;
    6)
      echo
      $WP_CMD user list --format=table 2>/dev/null
      read -rp "Enter username to delete: " U_DEL
      read -rp "Reassign posts to user ID (or leave blank to skip): " U_REASSIGN
      if [ -z "$U_REASSIGN" ]; then
        $WP_CMD user delete "$U_DEL" 2>/dev/null
      else
        $WP_CMD user delete "$U_DEL" --reassign="$U_REASSIGN" 2>/dev/null
      fi
      ;;
    7)
      echo
      read -rp "Old URL (e.g. http://old.com): " OLD_URL
      read -rp "New URL (e.g. https://new.com): " NEW_URL
      read -rp "Dry run first? (y/n): " DRY
      if [ "$DRY" = "y" ]; then
        $WP_CMD search-replace "$OLD_URL" "$NEW_URL" --all-tables --dry-run 2>/dev/null
        read -rp "Looks good? Run for real? (y/n): " REAL
        [ "$REAL" = "y" ] && $WP_CMD search-replace "$OLD_URL" "$NEW_URL" --all-tables 2>/dev/null
      else
        $WP_CMD search-replace "$OLD_URL" "$NEW_URL" --all-tables 2>/dev/null
      fi
      ;;
    8)
      echo
      $WP_CMD rewrite flush 2>/dev/null && echo -e "${GREEN}Rewrite rules flushed${NC}"
      ;;
    9)
      echo
      CACHE_DIR="$WP_PATH/wp-content/cache"
      if [ -d "$CACHE_DIR" ]; then
        rm -rf "${CACHE_DIR:?}"/*
        echo -e "${GREEN}Cache cleared: $CACHE_DIR${NC}"
      else
        echo "No cache directory found at $CACHE_DIR"
      fi
      ;;
    10)
      echo
      read -rp "Fix permissions in $(pwd)? This may take a moment. (y/n): " CONFIRM
      if [ "$CONFIRM" = "y" ]; then
        find "$WP_PATH" -type f -exec chmod 644 {} +
        find "$WP_PATH" -type d -exec chmod 755 {} +
        echo -e "${GREEN}Permissions fixed (files: 644, dirs: 755)${NC}"
      fi
      ;;
    11)
      echo
      read -rp "Delete completed + failed actions older than 3 months? (y/n): " CONFIRM
      if [ "$CONFIRM" = "y" ]; then
        $WP_CMD action-scheduler cleanup --status=complete --before="3 months ago" 2>/dev/null
        $WP_CMD action-scheduler cleanup --status=failed --before="3 months ago" 2>/dev/null
        echo -e "${GREEN}Done${NC}"
      fi
      ;;
    12)
      echo
      WP_VER=$($WP_CMD core version 2>/dev/null)
      read -rp "Reinstall core v${WP_VER} (skips wp-content)? (y/n): " CONFIRM
      [ "$CONFIRM" = "y" ] && $WP_CMD core download --force --skip-content --version="$WP_VER" 2>/dev/null
      ;;
    13)
      echo
      read -rp "Remove immutable flags from $(pwd)? (y/n): " CONFIRM
      [ "$CONFIRM" = "y" ] && chattr -R -i "$WP_PATH" 2>/dev/null && echo -e "${GREEN}Done${NC}"
      ;;
    q|Q)
      echo "Bye!"
      break
      ;;
    *)
      echo -e "${RED}Invalid choice${NC}"
      ;;
  esac
done

[ "$CLEANUP_WP" = "true" ] && rm -f /tmp/wp-cli.phar
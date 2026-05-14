#!/usr/bin/env bash
# ============================================================
# WORDPRESS TOOLKIT - Common WP-CLI operations
# Usage: bash wp_toolkit.sh [/path/to/wordpress]
# Works as root OR as a cPanel user (no root required)
# Compatible: cPanel, CloudLinux, AlmaLinux, CentOS
# ============================================================

WP_PATH="${1:-.}"

# Detect if running as root - only add --allow-root if needed
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

# ---- Validate WP install ----
if [ ! -f "$WP_PATH/wp-config.php" ]; then
  echo "ERROR: No wp-config.php found in: $WP_PATH"
  echo "Usage: $0 /home/user/public_html"
  exit 1
fi

echo "================================================================"
echo " WORDPRESS TOOLKIT"
echo " Path: $WP_PATH | User: $(whoami) | Date: $(date)"
echo "================================================================"

echo
echo "--- WordPress Info ---"
echo "Version:   $($WP_CMD core version 2>/dev/null)"
echo "Site URL:  $($WP_CMD option get siteurl 2>/dev/null)"
echo "Home URL:  $($WP_CMD option get home 2>/dev/null)"
echo "DB Prefix: $($WP_CMD config get table_prefix 2>/dev/null)"

echo
echo "--- Core Checksum Verify ---"
$WP_CMD core verify-checksums 2>/dev/null \
  && echo "Core files OK" \
  || echo "CHECKSUM MISMATCH - files may be modified or hacked"

echo
echo "--- Plugins (updates available) ---"
$WP_CMD plugin list --update=available --format=table 2>/dev/null || echo "(none or unable to check)"

echo
echo "--- All Plugins Status ---"
$WP_CMD plugin list --format=table 2>/dev/null

echo
echo "--- Admin Users ---"
$WP_CMD user list --role=administrator \
  --fields=ID,user_login,user_email,user_registered --format=table 2>/dev/null

echo
echo "--- Action Scheduler Stats ---"
$WP_CMD action-scheduler stats 2>/dev/null || echo "(Action Scheduler not active)"

echo
echo "--- PHP Version ---"
php -v 2>/dev/null | head -1

echo
echo "================================================================"
echo " Useful commands for this install:"
echo
echo "  Reinstall core:     wp core download --force --skip-content --path=$WP_PATH $ROOT_FLAG"
echo "  Search-replace URL: wp search-replace \'http://old.com\' \'https://new.com\' --all-tables --path=$WP_PATH $ROOT_FLAG"
echo "  Create admin user:  wp user create newadmin admin@domain.com --role=administrator --path=$WP_PATH $ROOT_FLAG"
echo "  Delete user:        wp user delete username --path=$WP_PATH $ROOT_FLAG"
echo "  Update all plugins: wp plugin update --all --path=$WP_PATH $ROOT_FLAG"
echo "  Flush rewrites:     wp rewrite flush --path=$WP_PATH $ROOT_FLAG"
echo "  Clear W3TC cache:   rm -rf $WP_PATH/wp-content/cache/*"
echo "  Fix permissions:    find $WP_PATH -type f -exec chmod 644 {} + && find $WP_PATH -type d -exec chmod 755 {} +"
echo "  Clean scheduler:    wp action-scheduler cleanup --status=complete --before=\'3 months ago\' --path=$WP_PATH $ROOT_FLAG"
echo "================================================================"

[ "$CLEANUP_WP" = "true" ] && rm -f /tmp/wp-cli.phar
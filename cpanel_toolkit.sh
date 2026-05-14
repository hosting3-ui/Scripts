#!/usr/bin/env bash
# ============================================================
# CPANEL TOOLKIT - Interactive WHM/cPanel Operations
# Run as: root
# Compatible: cPanel/WHM, CloudLinux, AlmaLinux, CentOS
# ============================================================

[ "$(id -u)" -ne 0 ] && echo "ERROR: Must be run as root" && exit 1

CYAN="\033[0;36m"; YELLOW="\033[1;33m"; GREEN="\033[0;32m"; RED="\033[0;31m"; DIM="\033[2m"; NC="\033[0m"

print_header() {
  clear
  echo -e "${CYAN}================================================================${NC}"
  echo -e " CPANEL TOOLKIT - $(hostname) - $(date +%H:%M)"
  ACCTS=$(ls /var/cpanel/users/ 2>/dev/null | wc -l)
  CPVER=$(cat /usr/local/cpanel/version 2>/dev/null || echo "N/A")
  echo -e " cPanel: ${CPVER} | Accounts: ${ACCTS}"
  echo -e "${CYAN}================================================================${NC}"
}

print_header

while true; do
  echo
  echo -e "${YELLOW}CPANEL / WHM OPERATIONS${NC}"
  echo "  --- Account Management ---"
  echo "  1)  Find domain owner"
  echo "  2)  List all accounts (with disk usage)"
  echo "  3)  Suspend account"
  echo "  4)  Unsuspend account"
  echo "  5)  Check account removal history (accounting.log)"
  echo "  6)  Create full backup (pkgacct)"
  echo "  7)  Restore from backup"
  echo "  --- Server / Config ---"
  echo "  8)  Fix quotas"
  echo "  9)  Rebuild Apache config + restart"
  echo " 10)  Fix missing vhost (rebuild + restart)"
  echo " 11)  Generate maildir size for account"
  echo " 12)  Check if domain exists on server (local/remote)"
  echo " 13)  Rebuild PHP config (rebuildphpconf)"
  echo " 14)  Update CageFS"
  echo "  --- PHP / CloudLinux ---"
  echo " 15)  Switch PHP version for one account"
  echo " 16)  Switch PHP SAPI for all accounts"
  echo " 17)  Extend PHP Selector limits (post_max_size etc.)"
  echo "  --- cPanel Login Audit ---"
  echo " 18)  Check failed logins for user/IP"
  echo " 19)  Check session log for user"
  echo "  --- Reseller ---"
  echo " 20)  List accounts per reseller"
  echo " 21)  Remove cPanel billing/support links for reseller"
  echo "   q) Quit"
  echo
  read -rp "Choice: " CHOICE

  case "$CHOICE" in
    1)
      read -rp "Domain: " DOM
      echo; /usr/local/cpanel/scripts/whoowns "$DOM" 2>/dev/null || grep -r "$DOM" /etc/userdomains 2>/dev/null | head -5
      ;;
    2)
      echo
      printf "%-20s %-10s %-15s %-10s\n" "USER" "PLAN" "DOMAIN" "DISK"
      echo "------------------------------------------------------------"
      for user in $(ls /var/cpanel/users/); do
        domain=$(grep "^DNS=" /var/cpanel/users/$user 2>/dev/null | head -1 | cut -d= -f2)
        plan=$(grep "^PLAN=" /var/cpanel/users/$user 2>/dev/null | cut -d= -f2)
        disk=$(du -sh /home/$user 2>/dev/null | awk '{print $1}')
        printf "%-20s %-10s %-15s %-10s\n" "$user" "$plan" "$domain" "$disk"
      done
      ;;
    3)
      read -rp "Username to suspend: " U
      read -rp "Reason: " REASON
      /usr/local/cpanel/scripts/suspendacct "$U" "$REASON" 2>/dev/null && echo -e "${GREEN}Suspended: $U${NC}"
      ;;
    4)
      read -rp "Username to unsuspend: " U
      /usr/local/cpanel/scripts/unsuspendacct "$U" 2>/dev/null && echo -e "${GREEN}Unsuspended: $U${NC}"
      ;;
    5)
      read -rp "Search term (domain, user, or leave blank for last 30): " TERM
      if [ -z "$TERM" ]; then
        grep "REMOVE" /var/cpanel/accounting.log 2>/dev/null | tail -30
      else
        grep -i "$TERM" /var/cpanel/accounting.log 2>/dev/null | tail -30
      fi
      ;;
    6)
      read -rp "Username to backup: " U
      echo "Running pkgacct for $U (this may take a while)..."
      /usr/local/cpanel/scripts/pkgacct "$U" 2>/dev/null && echo -e "${GREEN}Backup created in /home${NC}"
      ;;
    7)
      read -rp "Full path to backup file (.tar.gz): " BKFILE
      [ ! -f "$BKFILE" ] && echo -e "${RED}File not found${NC}" && continue
      read -rp "Skip account creation (account already exists)? (y/n): " SKIP
      if [ "$SKIP" = "y" ]; then
        /usr/local/cpanel/scripts/restorepkg --skipaccount "$BKFILE" 2>/dev/null
      else
        /usr/local/cpanel/scripts/restorepkg "$BKFILE" 2>/dev/null
      fi
      ;;
    8)
      echo "Running fixquotas..."
      /usr/local/cpanel/scripts/fixquotas 2>/dev/null && echo -e "${GREEN}Done${NC}"
      ;;
    9)
      echo "Rebuilding httpd.conf..."
      /usr/local/cpanel/scripts/rebuildhttpdconf 2>/dev/null
      systemctl restart httpd 2>/dev/null || service httpd restart 2>/dev/null
      echo -e "${GREEN}Apache restarted${NC}"
      ;;
    10)
      read -rp "Domain with missing vhost: " DOM
      /usr/local/cpanel/scripts/rebuildhttpdconf 2>/dev/null
      systemctl restart httpd 2>/dev/null || service httpd restart 2>/dev/null
      echo -e "${GREEN}Rebuilt and restarted${NC}"
      ;;
    11)
      read -rp "Username: " U
      /usr/local/cpanel/scripts/generate_maildirsize --confirm "$U" 2>/dev/null && echo -e "${GREEN}Done${NC}"
      ;;
    12)
      read -rp "Domain: " DOM
      echo "--- Local domains ---"
      grep "$DOM" /etc/localdomains 2>/dev/null || echo "(not in localdomains)"
      echo "--- Remote domains ---"
      grep "$DOM" /etc/remotedomains 2>/dev/null || echo "(not in remotedomains)"
      echo "--- userdomains ---"
      grep "$DOM" /etc/userdomains 2>/dev/null || echo "(not in userdomains)"
      ;;
    13)
      echo "Rebuilding PHP config..."
      /usr/local/cpanel/bin/rebuild_phpconf --current 2>/dev/null && echo -e "${GREEN}Done${NC}"
      ;;
    14)
      echo "Updating CageFS..."
      cagefsctl --force-update 2>/dev/null && echo -e "${GREEN}Done${NC}"
      ;;
    15)
      read -rp "Username: " U
      echo "Available versions:"; /usr/local/cpanel/bin/rebuild_phpconf --current 2>/dev/null | grep -oE "(ea|alt)-php[0-9]+" | sort -u
      read -rp "PHP version (e.g. ea-php82): " VER
      /usr/local/cpanel/bin/whmapi1 php_set_vhost_versions version="$VER" vhost="$(grep "^DNS=" /var/cpanel/users/$U 2>/dev/null | head -1 | cut -d= -f2)" 2>/dev/null         && echo -e "${GREEN}Set $U to $VER${NC}"
      ;;
    16)
      echo "Available SAPI: lsapi, fpm, cgi, suphp"
      read -rp "Target SAPI: " SAPI
      read -rp "Target PHP version (e.g. ea-php82): " VER
      /usr/local/cpanel/scripts/php_setrecommended "$VER" "$SAPI" 2>/dev/null         || /usr/bin/switchmodlsapi --enable-global 2>/dev/null
      echo -e "${GREEN}Done - rebuild PHP conf to confirm${NC}"
      ;;
    17)
      [ ! -f /etc/cl.selector/php.conf ] && echo "CloudLinux PHP selector not found" && continue
      echo "Current post_max_size range:"
      grep "post_max_size" /etc/cl.selector/php.conf | grep Range
      read -rp "New range (e.g. 2M,4M,8M,16M,32M,64M,128M,1G): " RANGE
      sed -i "s|.*post_max_size.*Range.*|  Range = $RANGE|" /etc/cl.selector/php.conf
      echo "Current upload_max_filesize range:"
      grep "upload_max_filesize" /etc/cl.selector/php.conf | grep Range
      read -rp "New range (or Enter to skip): " RANGE2
      [ -n "$RANGE2" ] && sed -i "s|.*upload_max_filesize.*Range.*|  Range = $RANGE2|" /etc/cl.selector/php.conf
      cagefsctl --force-update 2>/dev/null
      echo -e "${GREEN}Done - check cPanel PHP Selector for new values${NC}"
      ;;
    18)
      read -rp "Username or IP: " TERM
      echo "--- Login log ---"
      grep -i "$TERM" /usr/local/cpanel/logs/login_log 2>/dev/null | grep -i "FAIL\|fail\|invalid\|denied" | tail -30
      echo "--- cPanel access log ---"
      grep "$TERM" /usr/local/cpanel/logs/access_log 2>/dev/null | grep -i "login" | tail -20
      ;;
    19)
      read -rp "Username: " U
      grep "$U" /usr/local/cpanel/logs/session_log 2>/dev/null | grep "NEW" | cut -d" " -f1-3,5-6,8 | column -t | tail -30
      ;;
    20)
      echo
      for reseller in $(grep -l "RESELLER=" /var/cpanel/users/* 2>/dev/null | xargs grep -l "^RESELLER=1" | xargs -I{} basename {}); do
        count=$(grep -l "^OWNER=$reseller" /var/cpanel/users/* 2>/dev/null | wc -l)
        echo "Reseller: $reseller | Accounts: $count"
      done
      ;;
    21)
      read -rp "Reseller username: " U
      /usr/local/cpanel/bin/whmapi1 removeintegrationlink version=1 user="$U" app=WHMCSclientarea 2>/dev/null
      /usr/local/cpanel/bin/whmapi1 removeintegrationlink version=1 user="$U" app=knowledgebase 2>/dev/null
      echo -e "${GREEN}Billing/support links removed for $U${NC}"
      ;;
    q|Q) echo "Bye!"; break ;;
    *) echo -e "${RED}Invalid choice${NC}" ;;
  esac
done
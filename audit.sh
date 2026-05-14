#!/usr/bin/env bash
# ============================================================
# SECURITY AUDIT - Unauthorized Access / Compromised Server
# Compatible: CloudLinux, AlmaLinux, CentOS 7/8, cPanel
# ============================================================

RED='\033[0;31m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
section() { echo; echo -e "${CYAN}========== $1 ==========${NC}"; }

echo "================================================================"
echo " SECURITY AUDIT - $(hostname) - $(date)"
echo "================================================================"

section "RECENT LOGINS (last 20)"
last -F -i 2>/dev/null | head -20 || last -i | head -20

section "FAILED LOGIN ATTEMPTS"
lastb 2>/dev/null | head -20 || echo "(lastb requires root or /var/log/btmp access)"

section "LASTLOG - Recently active accounts (excluding never logged in)"
lastlog 2>/dev/null | grep -v "Never" | head -30

section "INTERACTIVE SHELL ACCOUNTS"
grep -v -E "nologin|false|sync|halt|shutdown" /etc/passwd

section "UID 0 ACCOUNTS (root equivalents)"
awk -F: '($3==0){print}' /etc/passwd

section "ROOT CRONTAB"
crontab -l -u root 2>/dev/null || echo "(none)"
echo; cat /etc/crontab 2>/dev/null
echo; echo "[/etc/cron.d/]"; ls -la /etc/cron.d/ 2>/dev/null
echo; echo "[/etc/cron.daily/]"; ls -la /etc/cron.daily/ 2>/dev/null

section "ALL USER CRONTABS"
for user in $(cut -f1 -d: /etc/passwd); do
  out=$(crontab -l -u "$user" 2>/dev/null)
  [ -n "$out" ] && echo "=== $user ===" && echo "$out"
done

section "AUTHORIZED_KEYS"
find /root /home -name "authorized_keys" 2>/dev/null -exec echo "=== {} ===" \; -exec cat {} \;

section "SUSPICIOUS BASHRC / PROFILE ENTRIES"
grep -rn "bash -i\|/dev/tcp\|nc \|curl\|wget" /home/*/.bashrc /etc/profile.d/ 2>/dev/null \
  && echo -e "${RED}^ Review the above!${NC}" || echo "Nothing suspicious found."

section "RUNNING SERVICES"
if command -v systemctl &>/dev/null; then
  systemctl list-units --type=service --state=running 2>/dev/null | head -50
else
  service --status-all 2>/dev/null | grep running | head -30
fi

section "CUSTOM SYSTEMD UNITS"
ls -la /etc/systemd/system/ 2>/dev/null | grep -v "^total\|@\|\->\|systemd" | head -20

section "MOTD FILES"
ls -la /etc/update-motd.d/ 2>/dev/null && cat /etc/update-motd.d/* 2>/dev/null

section "CPANEL FAILED LOGINS (last 30)"
grep -i "failed\|invalid" /usr/local/cpanel/logs/login_log 2>/dev/null | tail -30 \
  || echo "(cPanel not found or no log)"

section "OOM EVENTS"
grep -i "oom\|killed\|out of memory" /var/log/messages 2>/dev/null | tail -20 \
  || journalctl -k --no-pager 2>/dev/null | grep -i "oom\|killed" | tail -20

echo
echo "================================================================"
echo " AUDIT COMPLETE - $(date)"
echo "================================================================"
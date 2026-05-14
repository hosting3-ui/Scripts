#!/usr/bin/env bash
# ============================================================
# IP INVESTIGATOR - Search IP across all major logs
# Usage: bash ip_investigate.sh <IP>
# Compatible: cPanel, CloudLinux, AlmaLinux, CentOS
# ============================================================

if [ -z "$1" ]; then
  read -rp "Enter IP to investigate: " IP
else
  IP="$1"
fi

# Validate IP format
if ! echo "$IP" | grep -qE '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'; then
  echo "ERROR: Invalid IP format: $IP"
  exit 1
fi

echo "================================================================"
echo " IP INVESTIGATION: $IP - $(hostname) - $(date)"
echo "================================================================"

section() { echo; echo "--- $1 ---"; }

# IP geolookup
section "IP Info (whois)"
curl -s "https://ipinfo.io/$IP/json" 2>/dev/null | python3 -c \
  "import sys,json; d=json.load(sys.stdin); [print(f'{k}: {v}') for k,v in d.items() if k in ['ip','hostname','city','region','country','org','timezone']]" \
  2>/dev/null || whois "$IP" 2>/dev/null | grep -iE "netname|country|descr|abuse" | head -10

section "Active Connections from $IP"
ss -tn 2>/dev/null | grep "$IP" || netstat -tn 2>/dev/null | grep "$IP" || echo "(none)"

section "CSF / Firewall Status"
if command -v csf &>/dev/null; then
  csf -g "$IP" 2>/dev/null
else
  echo "(CSF not installed)"
fi

section "/var/log/secure (SSH)"
grep "$IP" /var/log/secure* 2>/dev/null | tail -20 \
  || journalctl _COMM=sshd 2>/dev/null | grep "$IP" | tail -20

section "/var/log/maillog"
grep "$IP" /var/log/maillog* 2>/dev/null | grep -i "auth\|fail\|login\|reject" | tail -20

section "/var/log/exim_mainlog"
grep "$IP" /var/log/exim_mainlog* 2>/dev/null | grep -i "fail\|reject\|auth\|spam" | tail -20

section "/var/log/lfd.log"
grep "$IP" /var/log/lfd.log 2>/dev/null | tail -20

section "cPanel access_log"
grep "$IP" /usr/local/cpanel/logs/access_log 2>/dev/null | tail -20

section "Apache access_log"
for log in /usr/local/apache/logs/access_log /etc/apache2/logs/access_log /var/log/httpd/access_log; do
  [ -f "$log" ] && grep "$IP" "$log" | tail -10 && break
done

section "/var/log/messages"
grep "$IP" /var/log/messages* 2>/dev/null | tail -20

echo
echo "================================================================"
echo " DONE"
echo "================================================================"
#!/usr/bin/env bash
# ============================================================
# FULL SERVER HEALTH CHECK
# Compatible: AlmaLinux, CloudLinux, CentOS, RHEL, cPanel/WHM
# Run as root for full output
# ============================================================

CYAN="\033[0;36m"
YELLOW="\033[1;33m"
GREEN="\033[0;32m"
RED="\033[0;31m"
MAGENTA="\033[0;35m"
BOLD="\033[1m"
DIM="\033[2m"
NC="\033[0m"

SEP="${CYAN}================================================================${NC}"
SUB="${DIM}----------------------------------------------------------------${NC}"

section() { echo; echo -e "$SEP"; echo -e "  ${BOLD}${YELLOW}$1${NC}"; echo -e "$SEP"; }
sub()     { echo; echo -e "  ${CYAN}▸ $1${NC}"; echo -e "$SUB"; }
ok()      { echo -e "  ${GREEN}✔${NC}  $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
bad()     { echo -e "  ${RED}✘${NC}  $1"; }
info()    { echo -e "  ${DIM}$1${NC}"; }

# ── Detect OS ──────────────────────────────────────────────
get_os() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "$NAME $VERSION_ID"
  elif [ -f /etc/redhat-release ]; then
    cat /etc/redhat-release
  else
    uname -s
  fi
}

IS_CPANEL=false
[ -f /usr/local/cpanel/version ] && IS_CPANEL=true

IS_CLOUDLINUX=false
uname -r | grep -qi "lve\|cloudlinux" && IS_CLOUDLINUX=true
[ -f /etc/cloudlinux-release ] && IS_CLOUDLINUX=true

IS_OPENVZ=false
[ -d /proc/user_beancounters ] && IS_OPENVZ=true

IS_KVM=false
systemd-detect-virt 2>/dev/null | grep -qi "kvm\|xen\|vmware\|microsoft" && IS_KVM=true

clear
echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════════════════════════╗"
echo "  ║           FULL SERVER HEALTH CHECK REPORT                   ║"
echo -e "  ║  $(date '+%Y-%m-%d %H:%M:%S %Z')                              ║"
echo "  ╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ══════════════════════════════════════════════════════════════
section "1. SERVER IDENTITY"
# ══════════════════════════════════════════════════════════════

sub "Hostname & OS"
echo "  Hostname   : $(hostname -f 2>/dev/null || hostname)"
echo "  Short name : $(hostname -s 2>/dev/null)"
echo "  OS         : $(get_os)"
echo "  Kernel     : $(uname -r)"
echo "  Arch       : $(uname -m)"
echo "  Virt       : $(systemd-detect-virt 2>/dev/null || echo 'unknown')"
$IS_CLOUDLINUX && echo "  CloudLinux : YES"
$IS_OPENVZ     && echo "  OpenVZ     : YES"
$IS_CPANEL     && echo "  cPanel     : $(cat /usr/local/cpanel/version 2>/dev/null)"

sub "Uptime & Load"
uptime
echo
LOAD1=$(awk '{print $1}' /proc/loadavg)
CPUS=$(nproc)
LOAD_WARN=$(echo "$LOAD1 $CPUS" | awk '{if ($1 > $2 * 1.5) print "HIGH"; else if ($1 > $2) print "ELEVATED"; else print "OK"}')
[ "$LOAD_WARN" = "HIGH" ]     && bad  "Load average HIGH: $LOAD1 ($(nproc) cores)" \
|| [ "$LOAD_WARN" = "ELEVATED" ] && warn "Load average elevated: $LOAD1 ($(nproc) cores)" \
|| ok "Load average normal: $LOAD1 ($(nproc) cores)"

sub "Network Interfaces & IPs"
ip -o addr show 2>/dev/null | awk '!/^[0-9]+: lo/ {printf "  %-10s %-20s %s\n", $2, $4, $9}' || ifconfig 2>/dev/null | grep -E 'inet |flags'
echo
echo -e "  ${DIM}Main IP (external):${NC}"
EXT_IP=$(curl -sf --max-time 5 http://myip.cpanel.net/v1.0/ 2>/dev/null || curl -sf --max-time 5 https://api.ipify.org 2>/dev/null || hostname -I | awk '{print $1}')
echo "  $EXT_IP"

sub "Open Listening Ports"
ss -tlnp 2>/dev/null | grep LISTEN | awk '{printf "  %-30s %s\n", $4, $6}' | sort | head -30

# ══════════════════════════════════════════════════════════════
section "2. HARDWARE RESOURCES"
# ══════════════════════════════════════════════════════════════

sub "CPU"
CPU_MODEL=$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
CPU_CORES=$(nproc)
CPU_PHYS=$(grep 'physical id' /proc/cpuinfo 2>/dev/null | sort -u | wc -l)
echo "  Model  : $CPU_MODEL"
echo "  Cores  : $CPU_CORES logical | $CPU_PHYS physical socket(s)"
echo
echo "  CPU Usage (2-sample):"
CPU_USAGE=$(top -bn2 | grep '%Cpu' | tail -1 | awk '{printf "%.1f", 100-$8}')
echo "  Usage  : ${CPU_USAGE}%"
[ "$(echo "$CPU_USAGE > 90" | bc -l 2>/dev/null)" = "1" ] && bad "CPU usage critical: ${CPU_USAGE}%" \
|| [ "$(echo "$CPU_USAGE > 70" | bc -l 2>/dev/null)" = "1" ] && warn "CPU usage elevated: ${CPU_USAGE}%" \
|| ok "CPU usage normal: ${CPU_USAGE}%"

sub "RAM & Swap"
free -h
echo
MEM_TOTAL=$(free -m | awk 'NR==2{print $2}')
MEM_USED=$(free -m  | awk 'NR==2{print $3}')
MEM_PCT=$(free -m   | awk 'NR==2{printf "%.0f", $3/$2*100}')
SWAP_TOTAL=$(free -m | awk 'NR==3{print $2}')
SWAP_USED=$(free -m  | awk 'NR==3{print $3}')

[ "$MEM_PCT" -ge 90 ] && bad  "RAM usage critical: ${MEM_PCT}% (${MEM_USED}MB / ${MEM_TOTAL}MB)" \
|| [ "$MEM_PCT" -ge 75 ] && warn "RAM usage elevated: ${MEM_PCT}% (${MEM_USED}MB / ${MEM_TOTAL}MB)" \
|| ok "RAM usage normal: ${MEM_PCT}% (${MEM_USED}MB / ${MEM_TOTAL}MB)"

if [ "$SWAP_TOTAL" -gt 0 ]; then
  SWAP_PCT=$(awk "BEGIN {printf \"%.0f\", $SWAP_USED/$SWAP_TOTAL*100}")
  [ "$SWAP_PCT" -ge 80 ] && bad  "Swap usage high: ${SWAP_PCT}% (${SWAP_USED}MB / ${SWAP_TOTAL}MB)" \
  || [ "$SWAP_PCT" -ge 40 ] && warn "Swap in use: ${SWAP_PCT}% (${SWAP_USED}MB / ${SWAP_TOTAL}MB)" \
  || ok "Swap normal: ${SWAP_PCT}% (${SWAP_USED}MB / ${SWAP_TOTAL}MB)"
else
  warn "No swap configured"
fi

sub "Disk Space"
df -hT | grep -v 'tmpfs\|devtmpfs\|udev\|cgmfs' | head -20
echo
df -hT | grep -v 'tmpfs\|devtmpfs\|udev\|cgmfs' | tail -n +2 | while read -r line; do
  PCT=$(echo "$line" | awk '{print $6}' | tr -d '%')
  MNT=$(echo "$line" | awk '{print $7}')
  [ -z "$PCT" ] && continue
  [ "$PCT" -ge 95 ] && bad  "CRITICAL disk usage on $MNT: ${PCT}%" \
  || [ "$PCT" -ge 85 ] && warn "High disk usage on $MNT: ${PCT}%" \
  || ok "Disk $MNT: ${PCT}% used"
done

sub "Inode Usage"
df -i | grep -v 'tmpfs\|devtmpfs' | tail -n +2 | while read -r line; do
  PCT=$(echo "$line" | awk '{print $5}' | tr -d '%')
  MNT=$(echo "$line" | awk '{print $6}')
  [ -z "$PCT" ] || [ "$PCT" = "-" ] && continue
  [ "$PCT" -ge 95 ] && bad  "CRITICAL inode usage on $MNT: ${PCT}%" \
  || [ "$PCT" -ge 80 ] && warn "High inode usage on $MNT: ${PCT}%" \
  || ok "Inodes $MNT: ${PCT}%"
done

sub "Disk I/O (iostat - 1 sample)"
if command -v iostat &>/dev/null; then
  iostat -dx 1 2 2>/dev/null | tail -n +4 | grep -v '^$' | head -10
else
  warn "iostat not available (install sysstat)"
  cat /proc/diskstats 2>/dev/null | awk '{print "  "$3, "reads:"$4, "writes:"$8}' | grep -v 'loop\|ram' | head -10
fi

# ══════════════════════════════════════════════════════════════
section "3. TOP PROCESSES"
# ══════════════════════════════════════════════════════════════

sub "Top 10 by CPU"
ps aux --sort=-%cpu 2>/dev/null | head -11 | awk 'NR==1{printf "  %-10s %-6s %-6s %-6s %s\n",$1,$2,$3,$4,$11} NR>1{printf "  %-10s %-6s %-6s %-6s %s\n",$1,$2,$3,$4,$11}'

sub "Top 10 by Memory"
ps aux --sort=-%mem 2>/dev/null | head -11 | awk 'NR==1{printf "  %-10s %-6s %-6s %-8s %s\n",$1,$2,$3,$4,$11} NR>1{printf "  %-10s %-6s %-6s %-8s %s\n",$1,$2,$3,$4,$11}'

sub "Zombie Processes"
ZOMBIES=$(ps aux 2>/dev/null | awk '$8=="Z"' | wc -l)
[ "$ZOMBIES" -gt 0 ] && warn "Zombie processes found: $ZOMBIES" || ok "No zombie processes"
ps aux 2>/dev/null | awk '$8=="Z"{print "  "$0}' | head -10

# ══════════════════════════════════════════════════════════════
section "4. SYSTEM ERRORS & EVENTS"
# ══════════════════════════════════════════════════════════════

sub "Recent Kernel Errors / Panics (dmesg)"
DMESG_ERRORS=$(dmesg --level=err,crit,alert,emerg 2>/dev/null | tail -20)
if [ -n "$DMESG_ERRORS" ]; then
  bad "Kernel errors found:"
  echo "$DMESG_ERRORS" | awk '{print "  "$0}' | head -20
else
  ok "No kernel errors in dmesg"
fi

sub "OOM Kills (last 24h)"
OOM=$(grep -i 'out of memory\|oom-kill\|oom_kill' /var/log/messages /var/log/kern.log 2>/dev/null | grep "$(date '+%b %e' 2>/dev/null)" | tail -10)
[ -n "$OOM" ] && bad "OOM events found:" && echo "$OOM" | awk '{print "  "$0}' || ok "No OOM events found"

sub "Segfaults (last 24h)"
SEGS=$(grep -i 'segfault\|general protection' /var/log/messages /var/log/kern.log 2>/dev/null | tail -5)
[ -n "$SEGS" ] && warn "Segfaults found:" && echo "$SEGS" | awk '{print "  "$0}' || ok "No segfaults found"

sub "Disk Errors (dmesg)"
DISK_ERR=$(dmesg 2>/dev/null | grep -iE 'error|I/O error|reset|failed|bad sector|hardware error' | grep -iE 'sd[a-z]|nvme|xvd|vd[a-z]' | tail -10)
[ -n "$DISK_ERR" ] && bad "Disk errors in dmesg:" && echo "$DISK_ERR" | awk '{print "  "$0}' || ok "No disk errors in dmesg"

sub "Systemd Failed Units"
if command -v systemctl &>/dev/null; then
  FAILED=$(systemctl --failed --no-legend 2>/dev/null | grep -v '^$')
  [ -n "$FAILED" ] && bad "Failed systemd units:" && echo "$FAILED" | awk '{print "  "$0}' || ok "No failed systemd units"
fi

sub "Last 10 System Log Errors (/var/log/messages)"
grep -iE 'error|critical|panic|failed|fatal' /var/log/messages 2>/dev/null | grep -v 'postfix\|named\|NetworkManager' | tail -10 | awk '{print "  "$0}'

# ══════════════════════════════════════════════════════════════
section "5. NETWORK & CONNECTIONS"
# ══════════════════════════════════════════════════════════════

sub "Connection Summary"
ss -s 2>/dev/null || netstat -s 2>/dev/null | head -20

sub "Top 10 IPs by Connection Count"
ss -tn 2>/dev/null | awk 'NR>1{print $5}' | cut -d: -f1 | sort | uniq -c | sort -rn | head -10 | awk '{printf "  %-8s %s\n", $1, $2}'

sub "SYN_RECV Connections (possible SYN flood)"
SYN=$(ss -tn 2>/dev/null | grep -c SYN_RECV || echo 0)
[ "$SYN" -gt 50 ] && bad "High SYN_RECV count: $SYN (possible SYN flood)" \
|| [ "$SYN" -gt 10 ] && warn "SYN_RECV: $SYN" \
|| ok "SYN_RECV normal: $SYN"

sub "TIME_WAIT Connections"
TW=$(ss -tn 2>/dev/null | grep -c TIME-WAIT || echo 0)
[ "$TW" -gt 5000 ] && warn "High TIME_WAIT: $TW" || ok "TIME_WAIT: $TW"

# ══════════════════════════════════════════════════════════════
section "6. SERVICES STATUS"
# ══════════════════════════════════════════════════════════════

sub "Core Services"
check_service() {
  local name="$1"; local display="$2"
  if systemctl is-active "$name" &>/dev/null 2>&1; then
    ok "$display is running"
  elif systemctl list-unit-files "$name.service" &>/dev/null 2>&1 | grep -q "$name"; then
    bad "$display is STOPPED"
  else
    info "$display not installed"
  fi
}

check_service "sshd"          "SSH"
check_service "httpd"         "Apache (httpd)"
check_service "lsws"          "LiteSpeed"
check_service "nginx"         "Nginx"
check_service "mysql"         "MySQL"
check_service "mariadb"       "MariaDB"
check_service "exim"          "Exim"
check_service "dovecot"       "Dovecot"
check_service "named"         "Named (DNS)"
check_service "csf"           "CSF Firewall"
check_service "lfd"           "LFD"
check_service "cpsrvd"        "cPanel (cpsrvd)"
check_service "cpanellogd"    "cPanel Log Daemon"
check_service "tailwatchd"    "cPanel Tailwatch"
check_service "chronyd"       "Chrony (NTP)"
check_service "ntpd"          "NTP"
check_service "firewalld"     "Firewalld"

# ══════════════════════════════════════════════════════════════
section "7. SECURITY CHECKS"
# ══════════════════════════════════════════════════════════════

sub "Root Login Activity (last 10)"
last root 2>/dev/null | head -10 | awk '{print "  "$0}'

sub "Failed SSH Logins (last 20)"
grep 'Failed password\|Invalid user\|authentication failure' /var/log/secure /var/log/auth.log 2>/dev/null | tail -20 | awk '{print "  "$0}'

sub "Top IPs with Failed SSH Auth"
grep 'Failed password\|Invalid user' /var/log/secure /var/log/auth.log 2>/dev/null | \
  grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | sort | uniq -c | sort -rn | head -10 | \
  awk '{printf "  %-8s %s\n", $1, $2}'

sub "UID 0 Accounts (should only be root)"
awk -F: '$3==0{print "  "$1}' /etc/passwd
UID0=$(awk -F: '$3==0' /etc/passwd | grep -v '^root:' | wc -l)
[ "$UID0" -gt 0 ] && bad "Non-root UID 0 accounts found!" || ok "Only root has UID 0"

sub "SUID/SGID Suspicious Binaries"
find /tmp /var/tmp /dev/shm -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | while read -r f; do
  bad "SUID/SGID in temp dir: $f"
done
SUID_COUNT=$(find /tmp /var/tmp /dev/shm -type f \( -perm -4000 -o -perm -2000 \) 2>/dev/null | wc -l)
[ "$SUID_COUNT" -eq 0 ] && ok "No SUID/SGID files in temp directories"

sub "World-Writable Files in /tmp with exec"
find /tmp /var/tmp -type f -perm -0111 2>/dev/null | head -10 | while read -r f; do
  warn "Executable in /tmp: $f"
done
EXEC_TMP=$(find /tmp /var/tmp -type f -perm -0111 2>/dev/null | wc -l)
[ "$EXEC_TMP" -eq 0 ] && ok "No executable files found in /tmp"

sub "Recently Modified Files in /tmp (24h)"
find /tmp /var/tmp /dev/shm -type f -mtime -1 2>/dev/null | head -15 | awk '{print "  "$0}'

sub "Suspicious PHP Patterns (cPanel homes - sampled)"
if $IS_CPANEL; then
  echo "  Scanning for eval(base64, system(, shell_exec in /home (first 10 hits)..."
  grep -rl --include="*.php" -E 'eval\(base64_decode|system\(.*\$_(GET|POST|REQUEST)|shell_exec\(\$_' \
    /home 2>/dev/null | head -10 | awk '{print "  [SUSPICIOUS] "$0}'
  SUSP=$(grep -rl --include="*.php" -E 'eval\(base64_decode|system\(.*\$_(GET|POST|REQUEST)|shell_exec\(\$_' \
    /home 2>/dev/null | wc -l)
  [ "$SUSP" -gt 0 ] && bad "Found $SUSP suspicious PHP file(s)" || ok "No obviously suspicious PHP files found"
fi

sub "CSF Blocked IPs Count"
if command -v csf &>/dev/null; then
  CSFD=$(csf -l 2>/dev/null | grep -c 'DENY\|DROP' || echo 0)
  ok "CSF active — $CSFD deny rules"
  echo "  Last 5 LFD blocks:"
  grep 'Blocked\|blocked' /var/log/lfd.log 2>/dev/null | tail -5 | awk '{print "  "$0}'
else
  warn "CSF not installed"
fi

# ══════════════════════════════════════════════════════════════
section "8. CPANEL / WHM (if applicable)"
# ══════════════════════════════════════════════════════════════

if $IS_CPANEL; then
  sub "cPanel Overview"
  ACCT_COUNT=$(ls /var/cpanel/users/ 2>/dev/null | wc -l)
  CPANEL_VER=$(cat /usr/local/cpanel/version 2>/dev/null)
  echo "  cPanel Version  : $CPANEL_VER"
  echo "  Total Accounts  : $ACCT_COUNT"

  sub "License Status"
  curl -sk --max-time 10 "https://verify.cpanel.net/app/verify?ip=${EXT_IP}" 2>/dev/null | \
    python3 -c "
import sys,re
h=sys.stdin.read()
r=re.search(r'class=\"status1\"(.*?)</tr>',h,re.DOTALL)
tds=re.findall(r'<td[^>]*>(.*?)</td>',r.group(1),re.DOTALL) if r else []
c=lambda s:re.sub(r'<[^>]+>','',s).strip()
if len(tds)>6:
    print('  Package : '+c(tds[2]))
    print('  Status  : '+c(tds[6]))
else:
    print('  Could not retrieve license info')
" 2>/dev/null || warn "Could not check cPanel license"

  sub "Top 10 Accounts by Disk"
  for user in $(ls /var/cpanel/users/ 2>/dev/null); do
    du -sh "/home/$user" 2>/dev/null | awk -v u="$user" '{print $1, u}'
  done | sort -hr | head -10 | awk '{printf "  %-10s %s\n", $1, $2}'

  sub "Suspended Accounts"
  SUSP_ACCTS=$(ls /var/cpanel/suspended/ 2>/dev/null | wc -l)
  [ "$SUSP_ACCTS" -gt 0 ] && warn "$SUSP_ACCTS suspended account(s):" && ls /var/cpanel/suspended/ 2>/dev/null | awk '{print "  "$0}' \
  || ok "No suspended accounts"

  sub "cPanel Error Log (last 10 errors)"
  grep -iE 'error|warn|fail|crit' /usr/local/cpanel/logs/error_log 2>/dev/null | tail -10 | awk '{print "  "$0}'

  sub "Apache Error Log (last 10)"
  tail -10 /usr/local/apache/logs/error_log 2>/dev/null | awk '{print "  "$0}'

  sub "Exim Queue"
  EXIM_Q=$(exim -bpc 2>/dev/null || echo 0)
  [ "$EXIM_Q" -gt 500 ] && bad  "Exim queue LARGE: $EXIM_Q messages" \
  || [ "$EXIM_Q" -gt 100 ] && warn "Exim queue elevated: $EXIM_Q messages" \
  || ok "Exim queue normal: $EXIM_Q messages"

  sub "Top Mail Senders (exim mainlog)"
  grep 'cwd=' /var/log/exim_mainlog 2>/dev/null | grep -oP 'cwd=\K[^ ]+' | sort | uniq -c | sort -rn | head -10 | \
    awk '{printf "  %-8s %s\n", $1, $2}'

else
  sub "cPanel not detected — skipping WHM checks"
  info "Not a cPanel server"
fi

# ══════════════════════════════════════════════════════════════
section "9. MYSQL / MARIADB"
# ══════════════════════════════════════════════════════════════

if command -v mysql &>/dev/null && mysqladmin status &>/dev/null 2>&1; then
  sub "MySQL Status"
  mysqladmin status 2>/dev/null | awk '{print "  "$0}'

  sub "Top 5 Largest Databases"
  mysql -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length+index_length)/1024/1024,1) AS 'Size_MB' FROM information_schema.tables GROUP BY table_schema ORDER BY 2 DESC LIMIT 5;" 2>/dev/null | awk '{printf "  %-30s %s\n", $1, $2}'

  sub "Long Running Queries (>10s)"
  mysql -e "SELECT id,user,host,db,time,info FROM information_schema.processlist WHERE command!='Sleep' AND time>10 ORDER BY time DESC;" 2>/dev/null | awk '{print "  "$0}'

  sub "Key MySQL Variables"
  mysql -e "SHOW VARIABLES LIKE 'innodb_buffer_pool_size';" 2>/dev/null | awk '{print "  "$0}'
  mysql -e "SHOW VARIABLES LIKE 'max_connections';" 2>/dev/null | awk '{print "  "$0}'
  mysql -e "SHOW STATUS LIKE 'Threads_connected';" 2>/dev/null | awk '{print "  "$0}'
  mysql -e "SHOW STATUS LIKE 'Aborted_connects';" 2>/dev/null | awk '{print "  "$0}'
  mysql -e "SHOW STATUS LIKE 'Slow_queries';" 2>/dev/null | awk '{print "  "$0}'
else
  sub "MySQL/MariaDB"
  warn "MySQL not running or not installed"
fi

# ══════════════════════════════════════════════════════════════
section "10. CLOUDLINUX / LVE"
# ══════════════════════════════════════════════════════════════

if $IS_CLOUDLINUX; then
  sub "LVE Stats (top faults)"
  if command -v lveps &>/dev/null; then
    lveps --by-fault 2>/dev/null | head -15 | awk '{print "  "$0}'
  elif command -v lveinfo &>/dev/null; then
    lveinfo --period=1h --by-fault --display-username 2>/dev/null | head -15 | awk '{print "  "$0}'
  else
    warn "lveps/lveinfo not found"
  fi

  sub "LVE Limits"
  lvectl list 2>/dev/null | head -10 | awk '{print "  "$0}'
else
  sub "CloudLinux"
  info "Not a CloudLinux server — skipping LVE checks"
fi

# ══════════════════════════════════════════════════════════════
section "11. MEMORY DETAIL"
# ══════════════════════════════════════════════════════════════

sub "Top 10 Processes by RSS Memory"
ps aux --sort=-%mem 2>/dev/null | awk 'NR==1 || NR<=11 {printf "  %-12s %-6s %-10s %s\n", $1, $2, $4, $11}' | head -11

sub "Shared Memory Segments"
ipcs -m 2>/dev/null | awk '{print "  "$0}' | head -10

if $IS_OPENVZ; then
  sub "OpenVZ Beancounters"
  cat /proc/user_beancounters 2>/dev/null | awk 'NR<=20{print "  "$0}'
fi

# ══════════════════════════════════════════════════════════════
section "12. SCHEDULED TASKS & CRONS"
# ══════════════════════════════════════════════════════════════

sub "Root Crontab"
crontab -l 2>/dev/null | awk '{print "  "$0}' || info "No root crontab"

sub "System Cron Jobs (/etc/cron.d)"
ls -la /etc/cron.d/ 2>/dev/null | awk '{print "  "$0}'

sub "Suspicious Cron Entries (curl/wget/bash -i)"
grep -rE 'curl|wget|bash -i|nc -e|/dev/tcp' /etc/cron* /var/spool/cron/ 2>/dev/null | head -10 | while read -r line; do
  bad "Suspicious cron: $line"
done
SUSP_CRON=$(grep -rE 'curl|wget|bash -i|nc -e|/dev/tcp' /etc/cron* /var/spool/cron/ 2>/dev/null | wc -l)
[ "$SUSP_CRON" -eq 0 ] && ok "No suspicious cron entries found"

# ══════════════════════════════════════════════════════════════
section "13. SYSTEM UPDATES"
# ══════════════════════════════════════════════════════════════

sub "Available Updates"
if command -v yum &>/dev/null; then
  UPDATE_COUNT=$(yum check-update --quiet 2>/dev/null | grep -v '^$\|^Loaded\|^Loading\|^Last\|^Obsoleting' | wc -l)
  [ "$UPDATE_COUNT" -gt 20 ] && bad  "$UPDATE_COUNT updates available" \
  || [ "$UPDATE_COUNT" -gt 0 ] && warn "$UPDATE_COUNT updates available" \
  || ok "System is up to date"
elif command -v dnf &>/dev/null; then
  UPDATE_COUNT=$(dnf check-update --quiet 2>/dev/null | grep -v '^$\|^Last\|^Loaded' | wc -l)
  [ "$UPDATE_COUNT" -gt 20 ] && bad  "$UPDATE_COUNT updates available" \
  || [ "$UPDATE_COUNT" -gt 0 ] && warn "$UPDATE_COUNT updates available" \
  || ok "System is up to date"
fi

sub "Last 5 Installed Packages"
rpm -qa --last 2>/dev/null | head -5 | awk '{print "  "$0}'

# ══════════════════════════════════════════════════════════════
section "SUMMARY"
# ══════════════════════════════════════════════════════════════
echo
echo -e "  ${BOLD}Report generated: $(date)${NC}"
echo -e "  ${BOLD}Hostname: $(hostname -f)${NC}"
echo -e "  ${BOLD}OS: $(get_os) | Kernel: $(uname -r)${NC}"
echo -e "  ${BOLD}Uptime: $(uptime -p 2>/dev/null || uptime)${NC}"
echo
echo -e "  ${GREEN}✔ = OK   ${YELLOW}⚠ = Warning   ${RED}✘ = Critical${NC}"
echo
echo -e "$SEP"

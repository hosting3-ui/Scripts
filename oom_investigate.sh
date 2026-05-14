#!/usr/bin/env bash
# ============================================================
# OOM / SERVER RESTART INVESTIGATION
# Compatible: CloudLinux, AlmaLinux, CentOS, OpenVZ, cPanel
# ============================================================

echo "================================================================"
echo " OOM / RESTART INVESTIGATION - $(hostname) - $(date)"
echo "================================================================"

section() { echo; echo "========== $1 =========="; }

section "REBOOT HISTORY"
last -x 2>/dev/null | grep -E "reboot|runlevel|shutdown" | head -20

section "OOM EVENTS - dmesg"
if dmesg -T &>/dev/null; then
  dmesg -T 2>/dev/null | grep -iE "oom|killed process|out of memory" | tail -30 \
    || echo "(no OOM events in dmesg)"
else
  dmesg 2>/dev/null | grep -iE "oom|killed process|out of memory" | tail -30 \
    || echo "(dmesg not available)"
fi

section "OOM EVENTS - /var/log/messages"
grep -iE "oom|killed|out of memory" /var/log/messages 2>/dev/null | tail -30 \
  || journalctl -k --no-pager 2>/dev/null | grep -iE "oom|killed" | tail -30 \
  || echo "(not found)"

section "KERNEL PANICS / LOCKUPS"
grep -iE "panic|BUG:|soft lockup|hard lockup|Call Trace" /var/log/messages 2>/dev/null | tail -20 \
  || journalctl -k --no-pager 2>/dev/null | grep -iE "panic|BUG:|lockup" | tail -20 \
  || echo "(none found)"

section "PREVIOUS BOOT JOURNAL (last 100 lines)"
journalctl -b -1 --no-pager 2>/dev/null | tail -100 \
  || echo "(previous boot journal not available - common on OpenVZ)"

section "CURRENT MEMORY STATUS"
free -m
echo; cat /proc/meminfo | grep -E "MemTotal|MemFree|MemAvailable|SwapTotal|SwapFree|Cached"

section "CLOUDLINUX BEANCOUNTERS (OpenVZ)"
if [ -f /proc/user_beancounters ]; then
  echo "Showing resources with non-zero failcnt:"
  cat /proc/user_beancounters | grep -vE "failcnt[[:space:]]+0|Version|uid|resource" \
    | awk '$NF > 0 {print}' | head -20 \
    || echo "(all failcnt are 0 - no resource limit hits)"
  echo; echo "physpages (RAM limit hit indicator):"
  grep physpages /proc/user_beancounters
else
  echo "(not an OpenVZ container)"
fi

section "LVE USAGE (CloudLinux)"
if command -v lveinfo &>/dev/null; then
  lveinfo --period=2h --display-username --show-all 2>/dev/null | head -30
else
  echo "(lveinfo not available)"
fi

section "SAR MEMORY - last 24h"
if command -v sar &>/dev/null; then
  sar -r 1>/dev/null 2>&1 && sar -r || echo "(sar data not available)"
else
  echo "(sysstat/sar not installed)"
fi

section "CURRENT TOP PROCESSES BY MEMORY"
ps -eo pid,user,%mem,%cpu,cmd --sort=-%mem | head -20
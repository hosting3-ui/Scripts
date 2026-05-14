#!/usr/bin/env bash

# System stats
printf "Total Memory: %sMB\nTotal CPU Cores: %s\nTotal Disk Space: %s\nDisk Usage: %s used of %s (%s)\nRAM Usage: %s used of %s (%s%%)\nCPU Usage: %s%%\n" \
  $(free -m | awk 'NR==2{print $2}') \
  $(nproc) \
  $(df -h --total | tail -1 | awk '{print $2}') \
  $(df -h --total | tail -1 | awk '{print $3}') \
  $(df -h --total | tail -1 | awk '{print $2}') \
  $(df -h --total | tail -1 | awk '{print $5}') \
  $(free -m | awk 'NR==2{print $3}') \
  $(free -m | awk 'NR==2{print $2}') \
  $(free -m | awk 'NR==2{printf "%.1f", $3/$2*100}') \
  $(top -bn2 | grep '%Cpu' | tail -1 | awk '{printf "%.1f", 100-$8}')

# cPanel info
CPANEL_ACCTS=$(whmapi1 listaccts want=user --output=json 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);print(len(d['data']['acct']))" 2>/dev/null)
[ -z "$CPANEL_ACCTS" ] && CPANEL_ACCTS=$(ls /var/cpanel/users/ 2>/dev/null | wc -l)
CPANEL_VER=$(cat /usr/local/cpanel/version 2>/dev/null)
SERVER_IP=$(curl -s http://myip.cpanel.net/v1.0/ 2>/dev/null || hostname -I | awk '{print $1}')

eval $(curl -sk "https://verify.cpanel.net/app/verify?ip=${SERVER_IP}" | python3 -c \
  "import sys,re;h=sys.stdin.read();r=re.search(r'class=\"status1\"(.*?)</tr>',h,re.DOTALL);tds=re.findall(r'<td[^>]*>(.*?)</td>',r.group(1),re.DOTALL) if r else [];c=lambda s:re.sub(r'<[^>]+>','',s).strip();print('P=\"'+c(tds[2])+'\" S=\"'+c(tds[6])+'\"') if len(tds)>6 else print('P=\"N/A\" S=\"Unable to retrieve\"')")

printf "cPanel Accounts: %s\ncPanel Version: %s\nLicense Package: %s\nLicense Status (%s): %s\n" \
  "$CPANEL_ACCTS" "$CPANEL_VER" "$P" "$SERVER_IP" "$S"
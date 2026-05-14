#!/usr/bin/env bash
# ============================================================
# MYSQL / MARIADB INTERACTIVE TOOLKIT
# Run as: root (or user with MySQL root access)
# Compatible: CloudLinux, AlmaLinux, CentOS, cPanel
# ============================================================

CYAN="\033[0;36m"; YELLOW="\033[1;33m"; GREEN="\033[0;32m"; RED="\033[0;31m"; NC="\033[0m"

# Detect service
MYSQL_SVC=""
for svc in mariadb mysqld mysql; do
  systemctl is-active "$svc" &>/dev/null && MYSQL_SVC="$svc" && break
done
[ -z "$MYSQL_SVC" ] && echo -e "${RED}ERROR: No MySQL/MariaDB service running${NC}" && exit 1

# Test connection
mysql -e "SELECT 1;" &>/dev/null || { echo -e "${RED}ERROR: Cannot connect to MySQL. Check credentials.${NC}"; exit 1; }

VER=$(mysql -se "SELECT VERSION();" 2>/dev/null)

clear
echo -e "${CYAN}================================================================${NC}"
echo -e " MYSQL TOOLKIT - $(hostname)"
echo -e " Service: ${MYSQL_SVC} | Version: ${VER}"
echo -e "${CYAN}================================================================${NC}"

while true; do
  echo
  echo -e "${YELLOW}MYSQL / MARIADB OPERATIONS${NC}"
  echo "  --- Monitoring ---"
  echo "  1)  Show full processlist"
  echo "  2)  Show only active/long-running queries"
  echo "  3)  Show key status (connections, slow queries, aborts)"
  echo "  4)  Show key variables (buffer pool, max_connections etc.)"
  echo "  5)  Show database sizes"
  echo "  --- Query Management ---"
  echo "  6)  Kill query by ID"
  echo "  7)  Kill all sleeping queries for a user"
  echo "  8)  Kill all queries over N seconds"
  echo "  --- Database Operations ---"
  echo "  9)  List all databases"
  echo " 10)  Dump database to file"
  echo " 11)  Import SQL file into database"
  echo " 12)  Drop a database (with confirmation)"
  echo " 13)  Create a database + user"
  echo "  --- Dump Fixes ---"
  echo " 14)  Fix DEFINER in dump file"
  echo " 15)  Fix collation in dump file"
  echo "  --- Configuration ---"
  echo " 16)  Tune innodb_buffer_pool_size interactively"
  echo " 17)  Tune max_connections interactively"
  echo " 18)  Check/set innodb_force_recovery"
  echo " 19)  Backup my.cnf and edit"
  echo " 20)  Restart MySQL service"
  echo "  --- Recovery ---"
  echo " 21)  Rotate InnoDB logs (fix corrupt ib_logfile)"
  echo "   q) Quit"
  echo
  read -rp "Choice: " CHOICE

  case "$CHOICE" in
    1)
      echo; mysql -e "SHOW FULL PROCESSLIST;" 2>/dev/null
      ;;
    2)
      read -rp "Show queries running longer than (seconds, default 5): " SECS
      SECS=${SECS:-5}
      mysql -e "SELECT ID,USER,HOST,DB,TIME,STATE,LEFT(INFO,80) AS QUERY FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND TIME > ${SECS} ORDER BY TIME DESC;" 2>/dev/null
      ;;
    3)
      echo
      for stat in Threads_connected Threads_running Slow_queries Aborted_connects Aborted_clients Questions Uptime; do
        val=$(mysql -se "SHOW GLOBAL STATUS LIKE '$stat';" 2>/dev/null | awk '{print $2}')
        printf "%-25s %s\n" "$stat" "$val"
      done
      ;;
    4)
      echo
      for var in innodb_buffer_pool_size max_connections key_buffer_size query_cache_size tmp_table_size wait_timeout innodb_force_recovery; do
        val=$(mysql -se "SHOW GLOBAL VARIABLES LIKE '$var';" 2>/dev/null | awk '{print $2}')
        printf "%-35s %s\n" "$var" "${val:-(not set)}"
      done
      ;;
    5)
      mysql -e "SELECT table_schema AS 'Database', ROUND(SUM(data_length+index_length)/1024/1024,2) AS 'Size_MB' FROM information_schema.tables GROUP BY table_schema ORDER BY SUM(data_length+index_length) DESC;" 2>/dev/null
      ;;
    6)
      mysql -e "SHOW FULL PROCESSLIST;" 2>/dev/null
      read -rp "Query ID to kill: " QID
      mysql -e "KILL $QID;" 2>/dev/null && echo -e "${GREEN}Killed $QID${NC}"
      ;;
    7)
      read -rp "MySQL username: " MUSER
      echo "Sleeping queries for $MUSER:"
      mysql -e "SELECT ID FROM information_schema.PROCESSLIST WHERE USER='$MUSER' AND COMMAND='Sleep';" 2>/dev/null
      read -rp "Kill them all? (y/n): " CONFIRM
      if [ "$CONFIRM" = "y" ]; then
        mysql -se "SELECT ID FROM information_schema.PROCESSLIST WHERE USER='$MUSER' AND COMMAND='Sleep';" 2>/dev/null |           while read id; do mysql -e "KILL $id;" 2>/dev/null; done
        echo -e "${GREEN}Done${NC}"
      fi
      ;;
    8)
      read -rp "Kill queries running longer than (seconds): " SECS
      mysql -se "SELECT ID FROM information_schema.PROCESSLIST WHERE COMMAND != 'Sleep' AND TIME > ${SECS};" 2>/dev/null |         while read id; do
          echo "Killing ID: $id"
          mysql -e "KILL $id;" 2>/dev/null
        done
      echo -e "${GREEN}Done${NC}"
      ;;
    9)
      mysql -e "SHOW DATABASES;" 2>/dev/null
      ;;
    10)
      mysql -e "SHOW DATABASES;" 2>/dev/null
      read -rp "Database name: " DB
      read -rp "Output file (default: /root/${DB}_$(date +%F).sql.gz): " OUTFILE
      OUTFILE=${OUTFILE:-/root/${DB}_$(date +%F).sql.gz}
      echo "Dumping $DB to $OUTFILE ..."
      mysqldump "$DB" --routines --triggers --events --single-transaction --quick --lock-tables=false 2>/dev/null | gzip > "$OUTFILE"
      echo -e "${GREEN}Done: $OUTFILE ($(du -sh "$OUTFILE" | cut -f1))${NC}"
      ;;
    11)
      mysql -e "SHOW DATABASES;" 2>/dev/null
      read -rp "Target database: " DB
      read -rp "SQL file to import: " SQLFILE
      [ ! -f "$SQLFILE" ] && echo -e "${RED}File not found${NC}" && continue
      echo "Importing $SQLFILE into $DB ..."
      if [[ "$SQLFILE" == *.gz ]]; then
        zcat "$SQLFILE" | mysql "$DB" 2>/dev/null
      else
        mysql "$DB" < "$SQLFILE" 2>/dev/null
      fi
      echo -e "${GREEN}Import complete${NC}"
      ;;
    12)
      mysql -e "SHOW DATABASES;" 2>/dev/null
      read -rp "Database to DROP: " DB
      read -rp "Are you SURE you want to drop '$DB'? Type the db name to confirm: " CONFIRM
      [ "$CONFIRM" = "$DB" ] && mysql -e "DROP DATABASE \`$DB\`;" 2>/dev/null && echo -e "${GREEN}Dropped $DB${NC}" || echo "Cancelled"
      ;;
    13)
      read -rp "New database name: " DB
      read -rp "New MySQL username: " MUSER
      read -rp "Password (leave blank to auto-generate): " MPASS
      [ -z "$MPASS" ] && MPASS=$(tr -dc 'A-Za-z0-9!@#%' < /dev/urandom | head -c 16)
      mysql -e "CREATE DATABASE IF NOT EXISTS \`$DB\`;" 2>/dev/null
      mysql -e "CREATE USER IF NOT EXISTS '$MUSER'@'localhost' IDENTIFIED BY '$MPASS';" 2>/dev/null
      mysql -e "GRANT ALL PRIVILEGES ON \`$DB\`.* TO '$MUSER'@'localhost'; FLUSH PRIVILEGES;" 2>/dev/null
      echo -e "${GREEN}Created DB: $DB | User: $MUSER | Pass: $MPASS${NC}"
      ;;
    14)
      read -rp "Dump file path: " DFILE
      [ ! -f "$DFILE" ] && echo -e "${RED}File not found${NC}" && continue
      read -rp "Old DEFINER user (e.g. olduser@localhost): " OLD_DEF
      read -rp "New DEFINER user (e.g. newuser@localhost): " NEW_DEF
      cp "$DFILE" "${DFILE}.bak"
      sed -i "s|DEFINER=\`${OLD_DEF}\`|DEFINER=\`${NEW_DEF}\`|g" "$DFILE"
      echo -e "${GREEN}Done - backup at ${DFILE}.bak${NC}"
      ;;
    15)
      read -rp "SQL file path: " DFILE
      [ ! -f "$DFILE" ] && echo -e "${RED}File not found${NC}" && continue
      read -rp "Old collation (e.g. utf8mb4_0900_ai_ci): " OLD_COL
      read -rp "New collation (e.g. utf8mb4_general_ci): " NEW_COL
      cp "$DFILE" "${DFILE}.bak"
      sed -i "s|$OLD_COL|$NEW_COL|g" "$DFILE"
      echo -e "${GREEN}Done - backup at ${DFILE}.bak${NC}"
      ;;
    16)
      RAM_MB=$(free -m | awk 'NR==2{print $2}')
      CURRENT=$(mysql -se "SHOW GLOBAL VARIABLES LIKE 'innodb_buffer_pool_size';" 2>/dev/null | awk '{print $2}')
      echo "Total RAM: ${RAM_MB}MB | Current buffer pool: ${CURRENT} bytes"
      echo "Recommended: ~70% of RAM for dedicated DB = $(( RAM_MB * 70 / 100 ))MB"
      read -rp "New value (e.g. 4G, 512M): " VAL
      # Update my.cnf
      if grep -q "innodb_buffer_pool_size" /etc/my.cnf 2>/dev/null; then
        sed -i "s|^innodb_buffer_pool_size.*|innodb_buffer_pool_size = $VAL|" /etc/my.cnf
      else
        echo "innodb_buffer_pool_size = $VAL" >> /etc/my.cnf
      fi
      echo -e "${GREEN}Set in /etc/my.cnf - restart MySQL to apply${NC}"
      read -rp "Restart MySQL now? (y/n): " RESTART
      [ "$RESTART" = "y" ] && systemctl restart "$MYSQL_SVC" && echo -e "${GREEN}Restarted${NC}"
      ;;
    17)
      CURRENT=$(mysql -se "SHOW GLOBAL VARIABLES LIKE 'max_connections';" 2>/dev/null | awk '{print $2}')
      echo "Current max_connections: $CURRENT"
      read -rp "New value (e.g. 300): " VAL
      mysql -e "SET GLOBAL max_connections = $VAL;" 2>/dev/null
      if grep -q "max_connections" /etc/my.cnf 2>/dev/null; then
        sed -i "s|^max_connections.*|max_connections = $VAL|" /etc/my.cnf
      else
        echo "max_connections = $VAL" >> /etc/my.cnf
      fi
      echo -e "${GREEN}Set live + saved to /etc/my.cnf${NC}"
      ;;
    18)
      CURRENT=$(grep -r "innodb_force_recovery" /etc/my.cnf /etc/my.cnf.d/ 2>/dev/null | head -1)
      echo "Current setting: ${CURRENT:-(not set, normal mode)}"
      echo "Values: 0=normal, 1-3=safe recovery, 4-6=data extraction only (destructive)"
      read -rp "Set innodb_force_recovery (0 to disable/remove): " VAL
      if [ "$VAL" = "0" ]; then
        sed -i "/innodb_force_recovery/d" /etc/my.cnf /etc/my.cnf.d/*.cnf 2>/dev/null
        echo -e "${GREEN}Removed innodb_force_recovery${NC}"
      else
        if grep -q "innodb_force_recovery" /etc/my.cnf 2>/dev/null; then
          sed -i "s|^innodb_force_recovery.*|innodb_force_recovery = $VAL|" /etc/my.cnf
        else
          echo "innodb_force_recovery = $VAL" >> /etc/my.cnf
        fi
        echo -e "${YELLOW}Set to $VAL - restart MySQL to apply${NC}"
      fi
      ;;
    19)
      cp /etc/my.cnf /etc/my.cnf.bak.$(date +%F_%H%M) 2>/dev/null
      echo -e "${GREEN}Backup created${NC}"
      ${EDITOR:-nano} /etc/my.cnf
      ;;
    20)
      read -rp "Restart $MYSQL_SVC? (y/n): " CONFIRM
      [ "$CONFIRM" = "y" ] && systemctl restart "$MYSQL_SVC" && echo -e "${GREEN}Restarted${NC}"
      ;;
    21)
      echo -e "${YELLOW}This rotates InnoDB log files to fix corruption (safe on shutdown).${NC}"
      read -rp "Proceed? (y/n): " CONFIRM
      if [ "$CONFIRM" = "y" ]; then
        mysql -e "SET GLOBAL innodb_fast_shutdown = 0;" 2>/dev/null
        systemctl stop "$MYSQL_SVC"
        mkdir -p /root/mysql_log_backup
        mv /var/lib/mysql/ib_logfile0 /root/mysql_log_backup/ 2>/dev/null
        mv /var/lib/mysql/ib_logfile1 /root/mysql_log_backup/ 2>/dev/null
        systemctl start "$MYSQL_SVC"
        echo -e "${GREEN}Done - MySQL restarted, new logs generated${NC}"
      fi
      ;;
    q|Q) echo "Bye!"; break ;;
    *) echo -e "${RED}Invalid choice${NC}" ;;
  esac
done
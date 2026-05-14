# 🛠️ Server Scripts

A collection of interactive server management scripts for cPanel/WHM, CloudLinux, AlmaLinux, and CentOS servers.

> **Run any script without leaving a file on the server:**
> ```bash
> bash <(curl -s https://raw.githubusercontent.com/hosting3-ui/Scripts/main/SCRIPT_NAME.sh)
> ```

***

## 🚀 Script Launcher (run all from one menu)

```bash
bash <(curl -s "https://raw.githubusercontent.com/hosting3-ui/Scripts/main/run.sh?$(date +%s)")
```

***

## 📋 Individual Scripts

### 🔐 License & Resources

**cPanel License & Resources check**
Displays server stats, cPanel version, account count, and license status.
```bash
bash <(curl -s https://raw.githubusercontent.com/hosting3-ui/Scripts/main/verify.sh)
```

***

**Inodes checker**
Shows inode usage per filesystem and top directories consuming inodes.
```bash
bash <(curl -s https://raw.githubusercontent.com/hosting3-ui/Scripts/main/inodes.sh)
```

***

### 🔒 Security & Audit

**VPS Security Audit**
Checks logins, failed auth, crontabs, authorized_keys, suspicious bashrc entries, UID 0 accounts, and OOM events.
```bash
bash <(curl -s https://raw.githubusercontent.com/hosting3-ui/Scripts/main/audit.sh)
```

***

**IP Investigate**
Searches an IP across all major logs — secure, maillog, exim, lfd, cPanel, Apache, messages. Includes live geo lookup and CSF status.
```bash
bash <(curl -s https://raw.githubusercontent.com/hosting3-ui/Scripts/main/ip_investigate.sh) 1.2.3.4
```

***

**OOM / Restart Investigation**
Full investigation — dmesg, kernel panics, beancounters (OpenVZ), LVE, SAR, previous boot journal, top memory processes.
```bash
bash <(curl -s https://raw.githubusercontent.com/hosting3-ui/Scripts/main/oom_investigate.sh)
```

***

### 🌐 WordPress

**WordPress Toolkit** *(works as root or cPanel user)*
Interactive menu — core checksum verify, plugin updates, admin user management, search-replace URL, flush rewrites, fix permissions, clear cache, clean Action Scheduler.
```bash
bash <(curl -s https://raw.githubusercontent.com/hosting3-ui/Scripts/main/wp_toolkit.sh)
```
> Run from inside the WordPress directory.

***

### ⚙️ cPanel / WHM

**cPanel Toolkit** *(root)*
Interactive menu — find domain owner, list accounts, suspend/unsuspend, accounting log, pkgacct backup/restore, fix quotas, rebuild Apache, PHP config, CageFS, login audit, reseller management.
```bash
bash <(curl -s https://raw.githubusercontent.com/hosting3-ui/Scripts/main/cpanel_toolkit.sh)
```

***

### 🗄️ Databases

**MySQL / MariaDB Toolkit** *(root)*
Interactive menu — processlist, kill queries, DB sizes, dump/import/drop/create databases, fix DEFINER/collation in dumps, tune buffer pool and max_connections, InnoDB log rotation.
```bash
bash <(curl -s https://raw.githubusercontent.com/hosting3-ui/Scripts/main/mysql_toolkit.sh)
```

***

### 📧 Email

**Exim Toolkit** *(root)*
Interactive menu — view/delete queue by sender/recipient/ID, frozen messages, log analysis, spam source by script path, auth failures, attempt frozen delivery.
```bash
bash <(curl -s https://raw.githubusercontent.com/hosting3-ui/Scripts/main/exim_toolkit.sh)
```

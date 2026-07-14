# Workshop: MySQL on Rocky Linux — Installation, Logging & Splunk Observability Cloud

**Duration:** ~2–3 hours
**Level:** Beginner to Intermediate
**OS:** Rocky Linux 9 (also works on Rocky Linux 8 with minor adjustments)

## Learning Objectives

1. Install and configure MySQL Server on Rocky Linux
2. Secure and tune a base MySQL installation
3. Enable and manage MySQL logs (error, general query, slow query)
4. Sign up for a Splunk Observability Cloud free trial
5. Ship MySQL metrics to Splunk Observability Cloud using the Splunk OpenTelemetry Collector
6. Build a basic dashboard/detector for MySQL health in Splunk Observability Cloud

---

## Prerequisites

- A Rocky Linux 9 VM/instance (2 vCPU, 4 GB RAM minimum) with `sudo` access
- Internet access from the VM (outbound HTTPS)
- A valid email address (for the Splunk Observability Cloud free trial signup)
- Basic familiarity with the Linux command line

---

## Part 1 — MySQL Installation on Rocky Linux

### 1.1 Update the system

```bash
sudo dnf update -y
sudo dnf install -y wget curl vim
```

### 1.2 Add the official MySQL Yum repository

```bash
sudo dnf install -y https://dev.mysql.com/get/mysql80-community-release-el9-1.noarch.rpm
sudo dnf module disable -y mysql
```

> Rocky Linux 8: replace `el9` with `el8` in the URL above.

### 1.3 Import the MySQL GPG signing keys

```bash
sudo curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql-2022 https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
sudo curl -o /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql-2023 https://repo.mysql.com/RPM-GPG-KEY-mysql-2023
sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql-2022
sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-mysql-2023
```

### 1.4 Point the repo file at both keys

```bash
sudo cp /etc/yum.repos.d/mysql-community.repo /etc/yum.repos.d/mysql-community.repo.bak
```

```bash
sudo tee /etc/yum.repos.d/mysql-community.repo > /dev/null << 'EOF'
[mysql-connectors-community]
name=MySQL Connectors Community
baseurl=https://repo.mysql.com/yum/mysql-connectors-community/el/9/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql-2022
       file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql-2023

[mysql-tools-community]
name=MySQL Tools Community
baseurl=https://repo.mysql.com/yum/mysql-tools-community/el/9/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql-2022
       file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql-2023

[mysql80-community]
name=MySQL 8.0 Community Server
baseurl=https://repo.mysql.com/yum/mysql-8.0-community/el/9/$basearch/
enabled=1
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql-2022
       file:///etc/pki/rpm-gpg/RPM-GPG-KEY-mysql-2023
EOF
```

```bash
sudo dnf clean all
sudo dnf repolist --all | grep -i mysql
```

### 1.5 Install MySQL Server

```bash
sudo dnf install -y mysql-community-server
```

### 1.6 Start and enable the service

```bash
sudo systemctl start mysqld
sudo systemctl enable mysqld
sudo systemctl status mysqld
```

### 1.7 Retrieve the temporary root password

```bash
sudo grep 'temporary password' /var/log/mysqld.log
```

### 1.8 Run the security script

```bash
sudo mysql_secure_installation
```

### 1.9 Verify installation

```bash
mysql -u root -p -e "SELECT VERSION();"
```

---

## Part 2 — MySQL Configuration

### 2.1 Key configuration file

```bash
sudo vim /etc/my.cnf
```

### 2.2 Recommended baseline settings

Add/adjust under `[mysqld]` in `/etc/my.cnf`:

```ini
[mysqld]
bind-address            = 0.0.0.0
max_connections         = 200
innodb_buffer_pool_size = 1G
character-set-server    = utf8mb4
collation-server        = utf8mb4_unicode_ci
```

### 2.3 Open the firewall (workshop lab only)

```bash
sudo firewall-cmd --permanent --add-port=3306/tcp
sudo firewall-cmd --reload
```

### 2.4 Restart MySQL to apply changes

```bash
sudo systemctl restart mysqld
```

### 2.5 Create a workshop database and user

```bash
mysql -u root -p
```

Run at the `mysql>` prompt:

```sql
CREATE DATABASE workshop_db;
CREATE USER 'workshop_user'@'%' IDENTIFIED BY 'StrongP@ssw0rd!';
GRANT ALL PRIVILEGES ON workshop_db.* TO 'workshop_user'@'%';
FLUSH PRIVILEGES;
```

---

## Part 3 — Database Logs & Monitoring

### 3.1 Error Log

```bash
sudo tail -f /var/log/mysqld.log
```

### 3.2 Create log files with correct ownership

```bash
sudo touch /var/log/mysql-general.log /var/log/mysql-slow.log
sudo chown mysql:mysql /var/log/mysql-general.log /var/log/mysql-slow.log
```

### 3.3 Handle SELinux

```bash
sudo dnf install -y policycoreutils-python-utils
sudo semanage fcontext -a -t mysqld_log_t "/var/log/mysql-general.log"
sudo semanage fcontext -a -t mysqld_log_t "/var/log/mysql-slow.log"
sudo restorecon -v /var/log/mysql-general.log /var/log/mysql-slow.log
```

### 3.4 General Query Log

Run at the `mysql>` prompt (`mysql -u root -p`):

```sql
SET GLOBAL general_log_file = '/var/log/mysql-general.log';
SET GLOBAL general_log = 'ON';
```

Or inline from bash:

```bash
mysql -u root -p -e "SET GLOBAL general_log_file = '/var/log/mysql-general.log'; SET GLOBAL general_log = 'ON';"
```

### 3.5 Slow Query Log

Add both the general log and slow query log settings to a single `[mysqld]` entry in `/etc/my.cnf`:

```ini
[mysqld]
general_log       = 1
general_log_file  = /var/log/mysql-general.log
slow_query_log      = 1
slow_query_log_file = /var/log/mysql-slow.log
long_query_time     = 2
log_queries_not_using_indexes = 1
```

```bash
sudo systemctl restart mysqld
mysql -u root -p -e "SHOW VARIABLES LIKE 'slow_query%';"
```

### 3.6 Generate sample load for logs (optional demo)

```bash
mysql -u root -p -e "SELECT SLEEP(3);"
mysql -u root -p workshop_db -e "SHOW TABLES;"
```

---

## Part 4 — Splunk Observability Cloud Free Trial

### 4.1 Sign up

1. Go to `https://www.splunk.com/en_us/products/observability.html` (or `https://www.signalfx.com/`)
2. Click **Start your free trial**
3. Register with your work email and create your organization/realm
4. Verify your email and log in

### 4.2 Get your Access Token and Realm

1. **Settings → Access Tokens** — create a new token (or use the default org token)
2. Note your **Realm** (shown in the URL, e.g., `us1`, `eu0`)

---

## Part 5 — Installing the Splunk OpenTelemetry Collector on Rocky Linux

### 5.1 Install via the installer script

```bash
export SPLUNK_ACCESS_TOKEN=<your-access-token>
export SPLUNK_REALM=<your-realm>

curl -sSL https://dl.signalfx.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh
sudo sh /tmp/splunk-otel-collector.sh \
  --realm "$SPLUNK_REALM" \
  -- "$SPLUNK_ACCESS_TOKEN" \
  --mode agent
```

```bash
sudo systemctl status splunk-otel-collector
```

### 5.2 Enable the MySQL receiver

```bash
sudo vim /etc/otel/collector/agent_config.yaml
```

```yaml
receivers:
  mysql:
    endpoint: localhost:3306
    username: workshop_user
    password: StrongP@ssw0rd!
    collection_interval: 30s

service:
  pipelines:
    metrics:
      receivers: [mysql, hostmetrics]
```

### 5.3 Restart the collector

```bash
sudo systemctl restart splunk-otel-collector
sudo systemctl status splunk-otel-collector
```

### 5.4 Verify data is flowing

- **Infrastructure → Hosts** — confirm your Rocky Linux host appears
- **Infrastructure → MySQL** — see metrics

---

## Part 6 — Build a Basic MySQL Dashboard & Detector

### 6.1 Create a dashboard

1. **Dashboards → New Dashboard** → name it `MySQL Workshop Dashboard`
2. Add charts for:
   - `mysql.threads`
   - `mysql.operations`
   - `mysql.buffer_pool.usage`
   - `mysql.slow_queries`

### 6.2 Create a detector (alert)

1. **Detectors → New Detector**
2. Choose metric `mysql.slow_queries` (or `Threads_connected`)
3. Set a static threshold rule, e.g., alert when slow queries rate > 5 per minute over a 5-minute window
4. Add a notification target (email, Slack, PagerDuty, etc.)
5. Save and activate

---

## Part 7 — Cleanup (Optional, End of Workshop)

```bash
sudo systemctl stop splunk-otel-collector
sudo systemctl disable splunk-otel-collector
sudo dnf remove -y splunk-otel-collector mysql-community-server
sudo rm -rf /var/lib/mysql /etc/my.cnf
```

---

## Appendix A — Troubleshooting Checklist

| Issue | Check |
|---|---|
| `GPG check FAILED` during install | Import both `RPM-GPG-KEY-mysql-2022` and `RPM-GPG-KEY-mysql-2023`, then update `gpgkey=` in `/etc/yum.repos.d/mysql-community.repo` |
| MySQL won't start | `sudo journalctl -u mysqld -n 50` |
| Can't connect remotely | Check `bind-address` in `/etc/my.cnf`, firewall rules, and security group/NSG |
| No metrics in Splunk | Check `sudo systemctl status splunk-otel-collector` and `/var/log/splunk-otel-collector/agent.log` |
| Slow query log empty | Confirm `slow_query_log=1` and `long_query_time` in `/etc/my.cnf` |

## Appendix B — Useful Reference Links

- MySQL Yum Repository: `https://dev.mysql.com/downloads/repo/yum/`
- MySQL Reference Manual: `https://dev.mysql.com/doc/refman/8.0/en/`
- Splunk OpenTelemetry Collector docs: `https://docs.splunk.com/observability/en/gdi/opentelemetry/opentelemetry.html`
- Splunk Observability Cloud MySQL integration: `https://docs.splunk.com/observability/en/gdi/monitors-databases/mysql.html`

---

*End of Workshop*

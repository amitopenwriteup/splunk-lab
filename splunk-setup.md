# Splunk Enterprise 10.4.0 — Setup Guide (Linux x86_64)

## Prerequisites

| Requirement | Details |
|-------------|---------|
| OS | RHEL / CentOS / Fedora (x86_64) |
| RAM | Minimum 4 GB (8 GB+ recommended) |
| Disk | Minimum 20 GB free |
| User | Root or sudo privileges |
| Ports | 8000 (Web UI), 9997 (Forwarder), 8089 (Management) |

---

## Step 1 — Download the RPM Package

```bash
wget -O splunk-10.4.0-f798d4d49089.x86_64.rpm \
  "https://download.splunk.com/products/splunk/releases/10.4.0/linux/splunk-10.4.0-f798d4d49089.x86_64.rpm"
```

### Verify the Download (Optional but Recommended)

```bash
# Check file size and integrity
ls -lh splunk-10.4.0-f798d4d49089.x86_64.rpm

# Verify RPM package signature
rpm --checksig splunk-10.4.0-f798d4d49089.x86_64.rpm
```

---

## Step 2 — Install Splunk

```bash
sudo rpm -ivh splunk-10.4.0-f798d4d49089.x86_64.rpm
```

> Splunk is installed to `/opt/splunk` by default.

---

## Step 3 — Start Splunk & Accept License

```bash
sudo /opt/splunk/bin/splunk start --accept-license
```

On first start, you will be prompted to:
- Set an **admin username** (default: `admin`)
- Set an **admin password** (minimum 8 characters)

---

## Step 4 — Enable Splunk to Start on Boot

```bash
sudo /opt/splunk/bin/splunk enable boot-start
```

For **systemd-based** systems (RHEL 7+):

```bash
sudo systemctl enable Splunkd
sudo systemctl start Splunkd
```

---

## Step 5 — Access the Web Interface

Open your browser and navigate to:

```
http://<your-server-ip>:8000
```

Login with the admin credentials set in Step 3.

---

## Common Management Commands

| Action | Command |
|--------|---------|
| Start Splunk | `sudo /opt/splunk/bin/splunk start` |
| Stop Splunk | `sudo /opt/splunk/bin/splunk stop` |
| Restart Splunk | `sudo /opt/splunk/bin/splunk restart` |
| Check status | `sudo /opt/splunk/bin/splunk status` |
| Check version | `sudo /opt/splunk/bin/splunk version` |
| Change admin password | `sudo /opt/splunk/bin/splunk edit user admin -password <newpass> -auth admin:<oldpass>` |

---

## Firewall Configuration

Open required ports if using `firewalld`:

```bash
sudo firewall-cmd --permanent --add-port=8000/tcp   # Web UI
sudo firewall-cmd --permanent --add-port=9997/tcp   # Splunk Forwarder
sudo firewall-cmd --permanent --add-port=8089/tcp   # REST API / Management
sudo firewall-cmd --reload
```

Or with `iptables`:

```bash
sudo iptables -A INPUT -p tcp --dport 8000 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 9997 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8089 -j ACCEPT
```

---

## Directory Structure

```
/opt/splunk/
├── bin/          # Splunk binaries and CLI
├── etc/          # Configuration files (inputs.conf, outputs.conf, etc.)
│   └── system/
│       └── local/
├── var/
│   ├── log/      # Splunk internal logs
│   └── lib/      # Index data storage
└── share/        # Web assets
```

---

## Key Configuration Files

| File | Purpose |
|------|---------|
| `$SPLUNK_HOME/etc/system/local/inputs.conf` | Define data inputs (files, ports, scripts) |
| `$SPLUNK_HOME/etc/system/local/outputs.conf` | Forward data to indexers |
| `$SPLUNK_HOME/etc/system/local/server.conf` | Server settings (hostname, license) |
| `$SPLUNK_HOME/etc/system/local/web.conf` | Web server settings (port, SSL) |
| `$SPLUNK_HOME/etc/system/local/indexes.conf` | Index definitions and retention |

---

## Adding a Data Input (Example: Monitor a Log File)

```bash
sudo /opt/splunk/bin/splunk add monitor /var/log/syslog -index main -sourcetype syslog
```

Or edit `inputs.conf` manually:

```ini
[monitor:///var/log/syslog]
index = main
sourcetype = syslog
```

---

## Uninstall Splunk

```bash
# Stop Splunk first
sudo /opt/splunk/bin/splunk stop

# Disable boot-start
sudo /opt/splunk/bin/splunk disable boot-start

# Remove the RPM package
sudo rpm -e splunk

# Remove data directory (optional — this deletes all indexed data)
sudo rm -rf /opt/splunk
```

---

## Troubleshooting

**Splunk won't start — port conflict:**
```bash
sudo netstat -tlnp | grep 8000
# Kill conflicting process or change Splunk web port in web.conf
```

**Check Splunk internal logs:**
```bash
tail -f /opt/splunk/var/log/splunk/splunkd.log
```

**Reset admin password (if forgotten):**
```bash
sudo /opt/splunk/bin/splunk edit user admin -password <newpassword> -auth admin:<oldpassword>
# If locked out, use:
sudo /opt/splunk/bin/splunk cmd splunkd rest --noauth POST /services/admin/users/admin password=<newpassword>
```

---

## References

- [Splunk Enterprise Documentation](https://docs.splunk.com/Documentation/Splunk)
- [Release Notes 10.4.0](https://docs.splunk.com/Documentation/Splunk/10.4.0/ReleaseNotes)
- [Splunk Community](https://community.splunk.com)

# Lab: Apache HTTP Server Instrumentation — Rocky Linux

**Objective:** Configure metrics collection for Apache HTTP Server on Rocky Linux, and validate it in Splunk Observability Cloud.

**Assumes:** The Splunk OTel Collector is already installed and running (`splunk-otel-collector` service active). This lab only covers application-level instrumentation.

**Estimated time:** 10–15 minutes

**Config file:** `/etc/otel/collector/agent_config.yaml`

**OS notes for Rocky Linux:** This version uses `dnf`, RHEL-style paths (`/etc/httpd/...`), and calls out `firewalld` and `SELinux` steps that Debian/Ubuntu doesn't need but Rocky enables by default.

---

## Lab Prerequisites

```bash
sudo systemctl status splunk-otel-collector
```

Confirm `active (running)` before continuing.

Back up the config before making any changes:

```bash
sudo cp /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.yaml.bak
```

Check whether SELinux is enforcing (it usually is on Rocky by default) — you'll need this later:

```bash
getenforce
```

> ⚠️ Throughout this lab, you will be **adding a receiver to an existing pipeline**, not creating a new `metrics:` key. YAML does not allow duplicate top-level keys — merge into the existing pipeline block instead.

---

## Part A — Apache HTTP Server

### Exercise 1 — Install Apache HTTP Server (`httpd`)

### Task
Install Apache if it isn't already present on the host.

### Steps

```bash
sudo dnf install -y httpd
```

Enable and start the service:

```bash
sudo systemctl enable httpd --now
```

If `firewalld` is active, open HTTP (and HTTPS if you'll use it):

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
```

### Validate

```bash
sudo systemctl status httpd

curl -I http://localhost/
```

**Expected:** `active (running)` and an `HTTP/1.1 200 OK` response.

---

### Exercise 2 — Enable `mod_status` on Apache

### Task
Expose Apache's internal status page so the collector can scrape it.

### Steps

On Rocky, `mod_status` ships with `httpd` and is usually already loaded via `/etc/httpd/conf.modules.d/00-base.conf` (look for `LoadModule status_module modules/mod_status.so`). There's no `a2enmod` equivalent — confirm it's loaded:

```bash
grep -i status_module /etc/httpd/conf.modules.d/00-base.conf
```

If it's commented out, uncomment that line.

Create the status config:

```bash
sudo nano /etc/httpd/conf.d/status.conf
```

```apacheconf
<Location "/server-status">
    SetHandler server-status
    Require local
</Location>
ExtendedStatus On
```

Restart Apache:

```bash
sudo systemctl restart httpd
```

### Validate mod_status directly

```bash
curl "http://localhost/server-status?auto"
```

**Expected:** plain-text output with fields like `Total Accesses`, `Total kBytes`, `BusyWorkers`, `IdleWorkers`.

> **SELinux note:** Since the collector scrapes `localhost` and `Require local` restricts access to the loopback interface, no SELinux booleans are needed for this step. You'd only need `httpd_can_network_connect` if Apache itself needed to reach out to a remote service.

---

### Exercise 3 — Add the Apache Receiver to the Collector

### Task
Configure the OTel Collector to scrape the Apache status endpoint.

### Steps

```bash
sudo nano /etc/otel/collector/agent_config.yaml
```

Add under `receivers:`:

```yaml
receivers:
  apache:
    endpoint: "http://localhost:80/server-status?auto"
    collection_interval: 10s
```

Merge `apache` into the existing `metrics:` pipeline's `receivers:` list:

```yaml
service:
  pipelines:
    metrics:
      receivers: [host_metrics, otlp, apache]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [signalfx]
```

Validate and restart:

```bash
sudo cp /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.yaml.bak2
sudo systemctl restart splunk-otel-collector
sudo systemctl status splunk-otel-collector
```

### Validate in the UI
1. **Metrics finder** → search `apache.requests`, `apache.workers`, `apache.traffic`.
2. **Infrastructure → Hosts → [host]** → confirm the Apache navigator/section appears.

---

## Final Validation Checklist

| Component | Metrics check | Trace check |
|---|---|---|
| Apache | `apache.requests` in Metrics finder | n/a (metrics only) |

---

## Troubleshooting

| Issue | Check |
|---|---|
| Apache metrics missing | Confirm `curl http://localhost/server-status?auto` returns data locally first |
| Collector restart fails | YAML syntax error — check for duplicate pipeline keys, confirm with `.bak` restore |
| Connection refused between hosts, port shows listening locally | Check `firewalld`: `sudo firewall-cmd --list-ports` and `sudo firewall-cmd --list-services` |
| Service works via `curl localhost` but fails from elsewhere / SELinux denials in logs | Check `sudo ausearch -m avc -ts recent` for denials; if httpd is blocked from an unusual port/socket, use `sudo semanage port -a -t http_port_t -p tcp <port>` or the appropriate `setsebool` (e.g. `httpd_can_network_connect`) rather than disabling SELinux |

---

## Cleanup (Optional)

```bash
sudo cp /etc/otel/collector/agent_config.yaml.bak /etc/otel/collector/agent_config.yaml
sudo systemctl restart splunk-otel-collector
```

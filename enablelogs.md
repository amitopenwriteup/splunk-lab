# Lab Part 2: Logs, Custom Metrics, Traces (APM), Tagging & Alerting

**Objective:** Building on Part 1, you will enable log collection, add a custom metric scraper, enable trace collection for APM, tag the host, and create an alert detector.

**Estimated time:** 20–25 minutes

**Prerequisite:** Complete **Part 1** (`lab-otel-collector-linux-part1.md`) first — the OTel Collector must already be installed and sending host metrics.

Continue using the same shell variables from Part 1:

```bash
export SPLUNK_REALM="<your-realm>"
export SPLUNK_ACCESS_TOKEN="<your-access-token>"
```

---

## Exercise 4 — Enable Log Collection

### Task
Turn on log ingestion using Fluentd.

### Steps

```bash
sudo sh /tmp/splunk-otel-collector.sh \
  --realm $SPLUNK_REALM \
  -- $SPLUNK_ACCESS_TOKEN \
  --mode agent \
  --with-fluentd
```

```bash
sudo systemctl status td-agent
```

### Validate
1. Go to **Logs** in the left nav of Splunk Observability Cloud.
2. Filter by your host name.
3. Confirm `/var/log/syslog` (or `/var/log/messages`) entries appear.

---

## Exercise 5 — Add a Custom Metric Scraper (Disk I/O)

### Task
Extend `hostmetrics` to include disk I/O scraping.

### Steps

```bash
sudo nano /etc/otel/collector/agent_config.yaml
```

Add under `hostmetrics.scrapers`:

```yaml
receivers:
  hostmetrics:
    collection_interval: 10s
    scrapers:
      cpu:
      memory:
      disk:
      filesystem:
      network:
      load:
      processes:
      paging:
```

Restart:

```bash
sudo systemctl restart splunk-otel-collector
```

### Validate
1. Go to **Metrics** in the left nav.
2. Search for `system.disk.io`.
3. Confirm data points are being received for your host.

---

## Exercise 6 — Enable Trace Collection (for APM)

### Task
Turn on the OTLP receiver so applications on this VM can send traces.

### Steps

Confirm this block exists in `agent_config.yaml`:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [batch, resourcedetection]
      exporters: [sapm]
```

Restart:

```bash
sudo systemctl restart splunk-otel-collector
```

### Validate

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:4318/v1/traces
```

**Expected result:** `400` (means the endpoint is up but rejected an empty request — this confirms it's listening).

---

## Exercise 7 — Send a Test Trace

### Task
Manually push a sample trace to confirm the pipeline end-to-end.

### Steps

```bash
curl -X POST http://localhost:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{"key": "service.name", "value": {"stringValue": "lab-test-service"}}]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "5b8aa5a2d2c872e8321cf37308d69df2",
          "spanId": "051581bf3cb55c13",
          "name": "lab-test-span",
          "startTimeUnixNano": "1700000000000000000",
          "endTimeUnixNano": "1700000001000000000"
        }]
      }]
    }]
  }'
```

### Validate
1. Go to **APM → Service Map**.
2. Search for `lab-test-service`.
3. Confirm the span appears within 1–2 minutes.

---

## Exercise 8 — Tag the Host

### Task
Add a custom tag to the VM for filtering in dashboards.

### Steps
1. In Splunk Observability Cloud, go to **Infrastructure → Hosts**.
2. Select your VM.
3. Click **Edit Properties**.
4. Add tag: `environment:lab`.
5. Save.

### Validate
Go to **Infrastructure → Hosts**, filter by `environment:lab`, and confirm your VM is the only result.

---

## Exercise 9 — Create a Basic Detector/Alert

### Task
Set up an alert on high CPU usage for this VM.

### Steps
1. Go to **Alerts → Detectors → New Detector**.
2. Signal: `cpu.utilization`.
3. Condition: **Static Threshold** → greater than `80` for `5 minutes`.
4. Scope: filter to your host's tag (`environment:lab`).
5. Add a notification (email is fine for lab purposes).
6. Save and activate.

### Validate
```bash
# Optional: generate CPU load to trigger the alert
sudo apt-get install -y stress-ng   # Debian/Ubuntu
stress-ng --cpu 4 --timeout 300s
```
Check **Alerts** in the UI for the detector firing within a few minutes.

---

## Lab Cleanup (Optional)

```bash
sudo systemctl stop splunk-otel-collector
sudo systemctl stop td-agent
sudo apt-get remove -y splunk-otel-collector td-agent   # Debian/Ubuntu
# or
sudo yum remove -y splunk-otel-collector td-agent       # RHEL/CentOS
```

Also delete the test detector and remove the `lab-test-service` if desired.

---

## Lab Summary — What You Configured (Parts 1 + 2)

| Component | Status |
|---|---|
| OTel Collector installed & running | ✅ |
| Host metrics (CPU, memory, disk, network) | ✅ |
| Log collection via Fluentd | ✅ |
| Custom disk I/O scraper | ✅ |
| OTLP trace receiver enabled | ✅ |
| Test trace sent and visible in APM | ✅ |
| Host tagged | ✅ |
| CPU alert detector created | ✅ |

---

## Next Steps

- Repeat the auto-instrumentation flow on a real application (Java/Node/Python) instead of the manual curl trace.
- Build a custom dashboard combining metrics, logs, and traces for this host.
- Explore **Data Management** in the left nav to review data volume and ingestion sources.

# Workshop: Configuring Splunk HEC Exporter on a Linux Collector

**Duration:** 45–60 minutes

**Objective:** Configure an existing OpenTelemetry Collector on Linux to send logs to Splunk via the Splunk HEC Exporter.

**Note:** This workshop assumes you already have the Splunk OpenTelemetry Collector installed on Linux — no Docker required.

---

## Lab Architecture

```text
Application Log File
        │
        ▼
Filelog Receiver
        │
        ▼
Batch Processor
        │
        ▼
Splunk HEC Exporter
        │
        ▼
Splunk Enterprise / Splunk Cloud
```

---

## Prerequisites

- Linux VM with Splunk OpenTelemetry Collector installed
- `sudo` access
- Splunk Enterprise or Splunk Cloud
- HEC enabled and a HEC token, plus a target index — set these up in **Lab 0** below if you don't have them yet
- Sample log file

---

## Lab 0 — Splunk Cloud Setup: Create an Index and Enable HEC

If you're using Splunk Cloud and don't yet have an index or HEC token, complete this section first.

### Step 1: Create an Index

1. Log in to your Splunk Cloud instance.
2. Go to **Settings → Indexes → New Index**.
3. Set:
   - **Index Name**: `workshop` (or reuse `main` if you prefer)
   - **Index Data Type**: `Events`
   - Leave other settings at their defaults for this workshop.
4. Click **Save**.

> If you use a custom index name like `workshop`, update every `index: "main"` reference later in this guide to `index: "workshop"`, and update your `index=main` searches to `index=workshop`.

### Step 2: Enable HTTP Event Collector (HEC)

1. Go to **Settings → Data Inputs → HTTP Event Collector**.
2. Click **Global Settings**.
3. Set **All Tokens** to **Enabled**, confirm the HEC port (default `8088`), and click **Save**.

### Step 3: Create a HEC Token

1. Still under **HTTP Event Collector**, click **New Token**.
2. **Name**: e.g. `otel-linux-workshop`.
3. Click **Next**.
4. **Input Settings**:
   - **Source name override**: leave blank (the collector sets `source` in its config)
   - **Sourcetype**: `otel` (matches the exporter config used later)
   - **Index**: select the index you created in Step 1 (`workshop` or `main`) and set it as the default
5. Click **Review**, then **Submit**.
6. Copy the generated **Token Value** immediately — you'll use it as `<YOUR_HEC_TOKEN>` in Lab 5.

### Step 4: Confirm Your HEC Endpoint

For Splunk Cloud, the HEC endpoint is typically:

```text
https://<your-splunk-cloud-host>:8088/services/collector
```

Splunk Cloud environments sometimes front HEC on port `443` instead of `8088` — check **Settings → Data Inputs → HTTP Event Collector** or with your Splunk Cloud admin if `8088` doesn't connect.

### Checkpoint

| Item | Status |
|---|---|
| Index created | ✅ |
| HEC globally enabled | ✅ |
| HEC token created and copied | ✅ |
| HEC endpoint and port confirmed | ✅ |

---

## Lab 1 — Verify the Collector

### Step 1: Check the Collector Service

```bash
sudo systemctl status splunk-otel-collector
```

Expected output:

```text
Active: active (running)
```

### Step 2: Check the Version

```bash
otelcol --version
```

or

```bash
/opt/splunk-otel-collector/bin/otelcol --version
```

### Step 3: Locate the Configuration File

Depending on the installation:

```bash
/etc/otel/collector/agent_config.yaml
```

or

```bash
/etc/otel/collector/config.yaml
```

For the Splunk distribution, it is commonly:

```bash
/etc/otel/collector/agent_config.yaml
```

---

## Lab 2 — Create a Sample Log File

```bash
sudo mkdir -p /var/log/workshop
sudo touch /var/log/workshop/app.log
```

Generate some logs:

```bash
echo "Application Started" | sudo tee -a /var/log/workshop/app.log
echo "User Login" | sudo tee -a /var/log/workshop/app.log
echo "Database Connected" | sudo tee -a /var/log/workshop/app.log
```

Verify:

```bash
cat /var/log/workshop/app.log
```

---

## Lab 3 — Configure the Filelog Receiver

Edit the collector configuration:

```bash
sudo vi /etc/otel/collector/agent_config.yaml
```

Add:

```yaml
receivers:
  filelog/workshop:
    include:
      - /var/log/workshop/app.log
    start_at: beginning
```

This tells the collector to monitor the log file from the beginning.

---

## Lab 4 — Configure the Batch Processor

```yaml
processors:
  batch:
```

The batch processor groups multiple log records before sending them, reducing the number of HTTP requests and improving performance.

---

## Lab 5 — Configure the Splunk HEC Exporter

Add:

```yaml
exporters:
  splunk_hec:
    token: "<YOUR_HEC_TOKEN>"
    endpoint: "https://<splunk-host>:8088/services/collector"
    source: "linux-workshop"
    sourcetype: "otel"
    index: "main"
    tls:
      insecure_skip_verify: true
```

Replace `<YOUR_HEC_TOKEN>` and `<splunk-host>` with your environment values.

---

## Lab 6 — Configure the Pipeline

```yaml
service:
  pipelines:
    logs:
      receivers:
        - filelog/workshop
      processors:
        - batch
      exporters:
        - splunk_hec
```

---

## Lab 7 — Validate the Configuration

Before restarting the service:

```bash
sudo otelcol validate --config=/etc/otel/collector/agent_config.yaml
```

If your installation doesn't include the `validate` command, restart the service and inspect the logs for configuration errors instead.

Expected:

```text
Configuration is valid
```

---

## Lab 8 — Restart the Collector

```bash
sudo systemctl restart splunk-otel-collector
sudo systemctl status splunk-otel-collector
```

---

## Lab 9 — Monitor Collector Logs

```bash
sudo journalctl -u splunk-otel-collector -f
```

Look for messages indicating:

- Filelog receiver started
- Pipeline initialized
- Exporter connected successfully

---

## Lab 10 — Generate More Logs

```bash
echo "Order Created" | sudo tee -a /var/log/workshop/app.log
echo "Payment Completed" | sudo tee -a /var/log/workshop/app.log
echo "Order Shipped" | sudo tee -a /var/log/workshop/app.log
```

The collector should automatically detect and forward these entries.

---

## Lab 11 — Verify in Splunk

Search:

```spl
index=main source=linux-workshop
```

or

```spl
index=main sourcetype=otel
```

You should see:

```text
Application Started
User Login
Database Connected
Order Created
Payment Completed
Order Shipped
```

---

## Lab 12 — Test Retry Behavior

Stop or block access to the Splunk HEC endpoint temporarily.

Generate logs:

```bash
echo "Retry Test" | sudo tee -a /var/log/workshop/app.log
```

Observe the collector logs:

```bash
sudo journalctl -u splunk-otel-collector -f
```

You should see retry attempts if `retry_on_failure` is enabled.

---

## Lab 13 — Enable a Sending Queue

```yaml
exporters:
  splunk_hec:
    sending_queue:
      enabled: true
      queue_size: 1000
```

Restart the collector and repeat the retry test to observe buffered log delivery after connectivity is restored.

---

## Lab 14 — Add Resource Attributes

```yaml
processors:
  resource:
    attributes:
      - key: environment
        value: workshop
        action: insert
      - key: os
        value: linux
        action: insert
```

Update the pipeline:

```yaml
processors:
  - resource
  - batch
```

Restart the collector and search in Splunk for:

```spl
environment=workshop
```

---

## Troubleshooting

| Issue | Check |
|---|---|
| No logs in Splunk | Verify the HEC endpoint, token, and index. |
| Collector won't start | Validate the YAML syntax and inspect `journalctl` output. |
| Log file not read | Confirm the path exists and the collector has read permissions. |
| TLS errors | Verify certificates or temporarily use `insecure_skip_verify: true` in a test environment. |
| HTTP 401 | The HEC token may be invalid or lack permission for the target index. |

---

## Next Steps

Once this basic lab is working, you can expand it to include:

1. Sending **metrics** with the `hostmetrics` receiver.
2. Sending **traces** from an instrumented application using the `otlp` receiver.
3. Using multiple exporters (for example, one for Splunk Enterprise and one for Splunk Observability Cloud).
4. Enabling exporter features such as compression, retry tuning, and persistent queues for production-ready deployments.

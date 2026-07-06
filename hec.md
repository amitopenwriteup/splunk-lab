# Hands-On Lab: Sending Data to Splunk Observability Cloud

**Duration:** ~60–90 minutes
**Level:** Beginner / Intermediate
**Goal:** By the end of this lab you will have sent metrics, traces, and logs into Splunk Observability Cloud using two methods — the Splunk Distribution of the OpenTelemetry Collector, and a direct REST/HTTP call — and verified the data in the UI.

---

## 1. Background

Splunk Observability Cloud is a separate product from Splunk Enterprise / Splunk Cloud Platform. It is a SaaS platform for infrastructure monitoring (IM), application performance monitoring (APM), real user monitoring (RUM), and log observability.

There are two main ways to get data in:

| Method | When to use it | What it sends |
|---|---|---|
| **Splunk Distribution of the OpenTelemetry Collector** | Recommended default for almost everything — hosts, containers, Kubernetes, apps | Metrics, traces, logs |
| **Direct REST / HTTP API calls** | Scripts, quick tests, systems that can't run a Collector, custom integrations | Metrics (OTLP), traces (OTLP), events |

This lab walks through both, so you understand the full picture, then practice the direct API path hands-on (fastest way to see data end-to-end without installing infrastructure).

> Note: Splunk Observability Cloud does **not** use the classic Splunk Enterprise "HTTP Event Collector" (HEC) token/endpoint for metrics and traces — that mechanism is specific to Splunk Enterprise/Cloud Platform indexes. Observability Cloud instead uses **org access tokens** and **OTLP (OpenTelemetry Protocol)** ingest endpoints. Existing logs already in Splunk Platform can still be viewed inside Observability Cloud via **Log Observer Connect** at no extra ingestion step.

---

## 2. Prerequisites

- [ ] A Splunk Observability Cloud org (a [free 14-day trial](https://www.splunk.com/en_us/products/observability.html) works)
- [ ] Your **realm** (for example `us0`, `us1`, `eu0`) — visible in your login URL, e.g. `https://app.us1.signalfx.com`
- [ ] An **org access token** (see Step 3 below)
- [ ] A machine with `curl` installed, and either:
  - Linux/macOS terminal access with `sudo`, **or**
  - Docker, if you'd rather run the Collector in a container
- [ ] Outbound HTTPS access to `*.signalfx.com` / `*.observability.splunkcloud.com`

---

## 3. Step 1 — Get Your Access Token and Realm

1. Log in to Splunk Observability Cloud.
2. Go to **Settings > Access Tokens**.
3. Click **New Token**, give it a name (e.g. `lab-workshop-token`), and save it.
4. Copy the token value somewhere safe — you'll use it as `{TOKEN}` throughout this lab.
5. Confirm your **realm** from the browser URL (the part after `app.` and before `.signalfx.com` / `.observability.splunkcloud.com`).

Set these as shell variables so the rest of the lab is copy/paste-friendly:

```bash
export SPLUNK_REALM="us1"          # replace with your realm
export SPLUNK_TOKEN="<YOUR_TOKEN>" # replace with your access token
```

---

## 4. Step 2 — Send a Metric Directly via the REST API

This is the fastest way to prove connectivity end-to-end before installing anything.

Splunk Observability Cloud accepts metrics over **OTLP/HTTP** at:

```
https://ingest.{REALM}.observability.splunkcloud.com/v2/datapoint/otlp
```

(Legacy hostname `https://ingest.{REALM}.signalfx.com/v2/datapoint/otlp` also works.)

### 4.1 Send a test metric (SignalFx JSON format, simpler for a first test)

```bash
curl -X POST "https://ingest.${SPLUNK_REALM}.signalfx.com/v2/datapoint" \
  -H "X-SF-Token: ${SPLUNK_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{
        "gauge": [
          {
            "metric": "workshop.lab.temperature",
            "value": 21.5,
            "dimensions": { "host": "lab-vm-01", "room": "workshop" }
          }
        ]
      }'
```

Expected response: `"OK"`

### 4.2 What just happened

- `X-SF-Token` authenticated the request — similar concept to a HEC token, but scoped to your Observability Cloud org, not a Splunk index.
- `gauge` created (or appended to) a metric named `workshop.lab.temperature`.
- `dimensions` are metadata you can filter and group by later, similar to `source`/`sourcetype` in HEC.

### 4.3 Verify it in the UI

1. Go to **Metric Finder** (or **Data Management > Metrics**) in Splunk Observability Cloud.
2. Search for `workshop.lab.temperature`.
3. You should see one data point plotted. Send it a few more times with different values to see a trend.

```bash
for v in 21.5 22.1 23.0 22.7; do
  curl -s -X POST "https://ingest.${SPLUNK_REALM}.signalfx.com/v2/datapoint" \
    -H "X-SF-Token: ${SPLUNK_TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"gauge\":[{\"metric\":\"workshop.lab.temperature\",\"value\":$v,\"dimensions\":{\"host\":\"lab-vm-01\",\"room\":\"workshop\"}}]}"
  sleep 5
done
```

---

## 5. Step 3 — Send a Trace via the REST API (OTLP)

Traces are sent as OTLP over HTTP to:

```
https://ingest.{REALM}.observability.splunkcloud.com/v2/trace/otlp
```

For this lab, the easiest way to generate a real trace is with the OpenTelemetry Collector (Step 4) rather than hand-crafting protobuf. If you want to test raw connectivity first, a minimal authenticated `curl` against the endpoint should return a `200` with an empty OTLP response body when given a valid (even minimal) OTLP payload — full payload construction is normally left to an SDK or the Collector, which is what production setups use.

---

## 6. Step 4 — Install the Splunk Distribution of the OpenTelemetry Collector

This is the recommended path for real workloads: one agent collects metrics, traces, and logs and forwards them all.

### 6.1 Linux quick install

```bash
curl -sSL https://dl.signalfx.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh
sudo sh /tmp/splunk-otel-collector.sh \
  --realm "$SPLUNK_REALM" \
  -- "$SPLUNK_TOKEN"
```

The installer will:
- Install the Collector as a system service
- Write a starter config to `/etc/otel/collector/agent_config.yaml`
- Start the service listening for OTLP, and also auto-collect host infrastructure metrics

### 6.2 Docker alternative

```bash
docker run -d --name otelcollector \
  -e SPLUNK_ACCESS_TOKEN="$SPLUNK_TOKEN" \
  -e SPLUNK_REALM="$SPLUNK_REALM" \
  -p 4317:4317 -p 4318:4318 \
  quay.io/signalfx/splunk-otel-collector:latest
```

### 6.3 Verify the Collector is running

```bash
sudo systemctl status splunk-otel-collector
# or, for Docker:
docker logs otelcollector --tail 50
```

### 6.4 Confirm host metrics are flowing

1. In Splunk Observability Cloud, go to **Infrastructure > Hosts**.
2. Your lab machine should appear within a couple of minutes, with CPU, memory, and disk metrics.

---

## 7. Step 5 — Send Logs Through the Collector

The Collector can tail log files and forward them as OpenTelemetry logs.

1. Edit the Collector config (commonly `/etc/otel/collector/agent_config.yaml`).
2. Add a `filelog` receiver pointing at a log file, and wire it into the `logs` pipeline:

```yaml
receivers:
  filelog:
    include: [ /var/log/workshop-app/*.log ]
    start_at: end

service:
  pipelines:
    logs:
      receivers: [filelog]
      processors: [batch]
      exporters: [splunk_hec]
```

3. Restart the Collector:

```bash
sudo systemctl restart splunk-otel-collector
```

4. Generate a test log line and confirm it appears in **Log Observer**:

```bash
sudo mkdir -p /var/log/workshop-app
echo "$(date) INFO workshop test log line" | sudo tee -a /var/log/workshop-app/app.log
```

---

## 8. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `401`/`403` from curl | Wrong or expired token | Regenerate token in **Settings > Access Tokens** |
| No data in Metric Finder | Wrong realm in URL | Double-check the realm from your browser's login URL |
| Collector service won't start | Port conflict or bad YAML | `journalctl -u splunk-otel-collector -n 100` to see the error |
| Host not appearing in Infrastructure | Firewall blocking outbound HTTPS | Confirm egress to `*.signalfx.com` / `*.observability.splunkcloud.com` |
| Logs not appearing | `filelog` receiver not in `logs` pipeline | Confirm the `service.pipelines.logs.receivers` list includes `filelog` |

---

## 9. Cleanup (Optional)

```bash
# Remove the Collector (Linux service install)
sudo /etc/otel/collector/uninstall.sh

# Or stop/remove the Docker container
docker rm -f otelcollector

# Delete the access token
# Settings > Access Tokens > lab-workshop-token > Delete
```

---

## 10. Recap

| You did | Using |
|---|---|
| Sent a test metric | Direct REST call (`X-SF-Token` header) |
| Verified it in the UI | Metric Finder |
| Installed an agent | Splunk Distribution of the OpenTelemetry Collector |
| Collected host infra metrics automatically | The Collector's built-in receivers |
| Forwarded application logs | `filelog` receiver → `logs` pipeline |

**Key takeaway:** for one-off tests or scripts, a direct authenticated HTTP call is enough. For real, ongoing workloads, install the OpenTelemetry Collector once per host/cluster and let it handle metrics, traces, and logs together.

---

## Appendix: Reference Endpoints

| Signal | Endpoint |
|---|---|
| Metrics (SignalFx JSON) | `https://ingest.{REALM}.signalfx.com/v2/datapoint` |
| Metrics (OTLP/HTTP) | `https://ingest.{REALM}.observability.splunkcloud.com/v2/datapoint/otlp` |
| Traces (OTLP/HTTP) | `https://ingest.{REALM}.observability.splunkcloud.com/v2/trace/otlp` |
| Events | `https://ingest.{REALM}.signalfx.com/v2/event` |

Replace `{REALM}` with your org's realm (e.g. `us0`, `us1`, `eu0`).

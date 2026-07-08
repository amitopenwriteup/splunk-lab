# Workshop: OpenTelemetry Collector → Splunk Observability Cloud Only (No Splunk Platform Required)

**Duration:** 30–45 minutes

**Scope:** This lab uses **only** Splunk Observability Cloud — no Splunk Cloud Platform, Splunk Enterprise, HEC index, or Log Observer Connect involved anywhere.

**Important scoping note, confirmed by live testing + Splunk documentation:**
Splunk Observability Cloud does **not** accept arbitrary application logs pushed directly via HEC (`https://ingest.<realm>.observability.splunkcloud.com/v1/log` returns `404` for generic log payloads — this was confirmed directly with `curl`). That endpoint is reserved for **AlwaysOn Profiling** data only. General log search/correlation in **Log Observer** requires **Log Observer Connect** to a Splunk Platform instance, which is out of scope here.

So within an Observability-Cloud-only scope, this lab covers the three things that genuinely work end-to-end without touching Splunk Platform:

1. **Metrics** → `signalfx` exporter
2. **Traces** → `otlp_http` exporter
3. **AlwaysOn Profiling data** (the one "log-shaped" signal Observability Cloud does accept directly) → `splunk_hec/profiling` exporter

If your real goal is searching plain application log lines in Log Observer, that requires Splunk Platform + Log Observer Connect — see the companion doc `workshop-splunk-hec-exporter-o11y-corrected.md`.

---

## Lab Architecture

```text
                     ┌──────────────────────────┐
Host Metrics ───────►│                          │───► signalfx exporter ───► Splunk Observability Cloud
                      │   OpenTelemetry          │                            (Infrastructure Monitoring)
App Traces ──────────►│   Collector              │───► otlp_http exporter ──► Splunk Observability Cloud
                      │                          │                            (APM)
Profiling Data ──────►│                          │───► splunk_hec/profiling ─► Splunk Observability Cloud
                     └──────────────────────────┘                            (AlwaysOn Profiling)
```

---

## Prerequisites

- Linux VM with Splunk OpenTelemetry Collector installed
- `sudo` access
- A Splunk Observability Cloud org
- Your **realm** and an **INGEST access token**

---

## Lab 0 — Get Your Realm and Access Token

### Step 1: Find your realm

Log in to Splunk Observability Cloud and check the browser URL:

```text
https://app.<REALM>.observability.splunkcloud.com
```

### Step 2: Create an access token

1. **Settings → Access Tokens → New Token**.
2. Name it, e.g. `otel-linux-o11y-workshop`.
3. Check **INGEST token** (not **API token with roles**).
4. **Create**, then copy the token — shown only once.

### Checkpoint

| Item | Status |
|---|---|
| Realm identified | ✅ |
| Ingest access token created and copied | ✅ |

---

## Lab 1 — Verify the Collector

```bash
sudo systemctl status splunk-otel-collector
otelcol --version
```

**Expected result:** `active (running)`.

Config location:

```bash
/etc/otel/collector/agent_config.yaml
```

---

## Lab 2 — Set Environment Variables

```bash
sudo vi /etc/otel/collector/splunk-otel-collector.conf
```

```bash
SPLUNK_ACCESS_TOKEN=<YOUR_INGEST_TOKEN>
SPLUNK_REALM=<your-realm>
SPLUNK_HEC_TOKEN=<YOUR_INGEST_TOKEN>
SPLUNK_MEMORY_TOTAL_MIB=512
```

Reload systemd so the values are picked up (this file is only read by systemd — not by manually-run `otelcol` commands):

```bash
sudo systemctl daemon-reload
```

> The default `agent_config.yaml` shipped with the collector already wires up `signalfx`, `otlp_http`, and `splunk_hec/profiling` using these same variables — in most installs you don't need to hand-write these blocks from scratch. The steps below show what to check/confirm.

---

## Lab 3 — Confirm the Metrics Pipeline (signalfx exporter)

```yaml
exporters:
  signalfx:
    access_token: "${SPLUNK_ACCESS_TOKEN}"
    realm: "${SPLUNK_REALM}"
```

```yaml
service:
  pipelines:
    metrics:
      receivers:
        - hostmetrics
        - otlp
      processors:
        - batch
      exporters:
        - signalfx
```

**Verify:** once running, check the journal for a host metadata sync — this confirms the token/realm pair is valid:

```bash
sudo journalctl -u splunk-otel-collector -f | grep -i "hostmetadata"
```

Expect a line like `Host metadata synchronized`.

---

## Lab 4 — Confirm the Traces Pipeline (otlp_http exporter)

```yaml
exporters:
  otlp_http:
    traces_endpoint: "https://ingest.${SPLUNK_REALM}.observability.splunkcloud.com/v2/trace/otlp"
    headers:
      X-SF-Token: "${SPLUNK_ACCESS_TOKEN}"
```

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
```

```yaml
service:
  pipelines:
    traces:
      receivers:
        - otlp
      processors:
        - batch
      exporters:
        - otlp_http
```

**Test with a curl-based OTLP trace** (optional smoke test) or point any OTLP-instrumented app at `localhost:4318`.

---

## Lab 5 — Configure AlwaysOn Profiling (splunk_hec/profiling exporter)

This is the one log-shaped signal Observability Cloud does accept directly at `/v1/log` — but only in this specific shape, fed by a dedicated profiling receiver, not a generic `filelog` receiver.

```yaml
receivers:
  otlp/profiling:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4319
```

```yaml
exporters:
  splunk_hec/profiling:
    token: "${SPLUNK_HEC_TOKEN}"
    endpoint: "https://ingest.${SPLUNK_REALM}.observability.splunkcloud.com/v1/log"
    source: "otel"
    sourcetype: "otel"
    log_data_enabled: false
```

```yaml
service:
  pipelines:
    logs/profiling:
      receivers:
        - otlp/profiling
      exporters:
        - splunk_hec/profiling
```

> Configure your application's Splunk OTel agent/instrumentation to enable AlwaysOn Profiling and point `SPLUNK_PROFILER_LOGS_ENDPOINT` at port `4319` on this collector.

> Do **not** wire a `filelog` receiver into `splunk_hec/profiling` — this exporter is not designed to accept arbitrary log lines, and doing so returns `404`.

---

## Lab 6 — Verify TLS (Optional, Before Disabling Verification)

```bash
openssl s_client -connect ingest.<your-realm>.observability.splunkcloud.com:443 -servername ingest.<your-realm>.observability.splunkcloud.com </dev/null 2>/dev/null | openssl x509 -noout -dates -issuer
```

Observability Cloud's ingest endpoints use publicly trusted certificates — `insecure_skip_verify` should not be needed for this lab.

---

## Lab 7 — Validate and Restart

`otelcol validate` run directly in a shell does **not** read the systemd `EnvironmentFile` — source it first if you want local validation to succeed:

```bash
set -a
source /etc/otel/collector/splunk-otel-collector.conf
set +a
sudo -E otelcol validate --config=/etc/otel/collector/agent_config.yaml
```

Then restart the real service:

```bash
sudo systemctl restart splunk-otel-collector
sudo systemctl status splunk-otel-collector
```

---

## Lab 8 — Monitor Collector Logs

```bash
sudo journalctl -u splunk-otel-collector -f
```

Look for:
- `Host metadata synchronized` (metrics working)
- No repeated `error`/`404`/retry lines from `signalfx`, `otlp_http`, or `splunk_hec/profiling`

---

## Lab 9 — Verify in Splunk Observability Cloud

1. **Infrastructure Monitoring** → confirm your host appears with metrics flowing.
2. **APM** → confirm traces appear if you sent any.
3. **AlwaysOn Profiling** (within APM, per-service) → confirm profiling data if configured in Lab 5.

---

## Troubleshooting

| Issue | Check |
|---|---|
| `signalfx` error: "requires a non-empty access_token" | Confirm `EnvironmentFile` is wired to the unit: `systemctl cat splunk-otel-collector \| grep -i EnvironmentFile`, and that you ran `daemon-reload` + restarted (not just validated manually). |
| `HTTP 404` from `splunk_hec/profiling` on `/v1/log` | Confirm you're sending profiling-shaped data from `otlp/profiling`, not generic log lines from a `filelog` receiver. |
| `HTTP 401` on any exporter | Token invalid/expired, or not an INGEST-scoped token; confirm `SPLUNK_REALM` matches your org (check the browser URL from Lab 0). |
| No metrics in Infrastructure Monitoring | Check `journalctl` for `hostmetadata` sync errors; verify realm and token again. |
| Collector won't start | Validate YAML syntax; inspect `journalctl -u splunk-otel-collector`. |
| You actually need to search plain app log lines | Not possible purely within Observability Cloud — requires Splunk Platform + Log Observer Connect. See the companion "corrected" workshop doc. |

---

## Security Note

Treat any token pasted into tickets, chats, or shared docs as compromised — rotate it immediately via **Settings → Access Tokens**.

---

## Next Steps

- Add `deployment.environment` and custom resource attributes via the `resource` processor.
- Ensure `resourcedetection` runs before other processors so `host.name` populates and correlates metrics/traces/profiling.
- If log search becomes a requirement later, revisit the Log Observer Connect path (Splunk Platform required).

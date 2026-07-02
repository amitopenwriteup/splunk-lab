# Traffic, CPU/Memory & Disk Monitoring — Configuration Guide

**Assumes:** the Splunk OTel Collector is already installed and running as a service on the host (Linux or Windows). This guide only covers enabling and validating the three specific metric groups below.

---

## Config File Location

| OS | Path |
|---|---|
| Linux | `/etc/otel/collector/agent_config.yaml` |
| Windows | `C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml` |

> Windows note: binaries live in `Program Files`, but the editable config is under `ProgramData` — always edit the copy there.

**Always back up before editing:**

```bash
# Linux
sudo cp /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.yaml.bak
```

```powershell
# Windows
Copy-Item "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml" "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml.bak"
```

---

## 1. CPU / Memory Monitoring

### Configure

These are enabled by default under the `host_metrics` receiver. Confirm both scrapers are present:

```yaml
receivers:
  host_metrics:
    collection_interval: 10s
    scrapers:
      cpu:
      memory:
```

For per-process CPU/memory breakdowns (top consumers), add the `process` scraper:

```yaml
receivers:
  host_metrics:
    collection_interval: 10s
    scrapers:
      cpu:
      memory:
      process:
      processes:
```

### Restart

```bash
sudo systemctl restart splunk-otel-collector          # Linux
```
```powershell
Restart-Service splunk-otel-collector                  # Windows
```

### Validate

- **Metrics finder** → search `cpu.utilization`, `memory.utilization`
- **Infrastructure → Hosts → [host]** → CPU and Memory panels should show live data within 1–2 minutes

### Key metrics

| Metric | Meaning |
|---|---|
| `cpu.utilization` | % CPU used, per core or aggregate |
| `cpu.num_processors` | Logical CPU count |
| `memory.utilization` | % memory used |
| `memory.usage` | Memory used, in bytes, by state (used/free/cached) |

---

## 2. Disk Monitoring

### Configure

Enable the `disk` and `filesystem` scrapers:

```yaml
receivers:
  host_metrics:
    collection_interval: 10s
    scrapers:
      disk:
      filesystem:
      paging:
```

- `disk` — read/write throughput and I/O operations
- `filesystem` — capacity used/free per mount point
- `paging` — swap usage (early indicator of memory pressure affecting disk)

Optional: exclude specific filesystems/mounts from noise (e.g., tmpfs, overlay):

```yaml
receivers:
  host_metrics:
    scrapers:
      filesystem:
        exclude_mount_points:
          match_type: regexp
          mount_points: ["/dev*", "/run*", "/snap*"]
        exclude_fs_types:
          match_type: strict
          fs_types: ["tmpfs", "squashfs", "overlay"]
```

### Restart and validate

Same restart commands as above. Then check:

- **Metrics finder** → search `disk.io`, `disk.operations`, `system.filesystem.utilization`
- **Infrastructure → Hosts → [host]** → Disk panel

### Key metrics

| Metric | Meaning |
|---|---|
| `disk.io` | Bytes read/written |
| `disk.operations` | Read/write operation count |
| `disk.io_time` | Time spent on I/O (contention indicator) |
| `system.filesystem.utilization` | % disk space used per mount |
| `system.filesystem.usage` | Bytes used/free per mount |

---

## 3. Traffic (Network) Monitoring

### Configure

Enable the `network` scraper for interface-level throughput, packets, and errors:

```yaml
receivers:
  host_metrics:
    collection_interval: 10s
    scrapers:
      network:
```

For **application-level traffic** (HTTP/gRPC request rates, latency, error rates between services), that comes from APM traces, not `host_metrics`. Confirm the OTLP receiver and traces pipeline are enabled instead:

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
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [otlp_http]
```

This requires the application on the host to be instrumented (auto or manual) — see APM setup if not already done.

### Restart and validate

- **Metrics finder** → search `network.io`, `network.packets`, `network.errors`
- **Infrastructure → Hosts → [host]** → Network panel
- **APM → Service Map** → for application-level request traffic (requires instrumentation)

### Key metrics

| Metric | Meaning |
|---|---|
| `network.io` | Bytes sent/received per interface |
| `network.packets` | Packets sent/received |
| `network.errors` | Send/receive errors — watch for non-zero values |
| `network.connections` | Active connection count |

---

## Combined Example — Minimal `host_metrics` Block

```yaml
receivers:
  host_metrics:
    collection_interval: 10s
    scrapers:
      cpu:
      memory:
      disk:
      filesystem:
      network:
      paging:
      processes:
```

Make sure this receiver is included in the `metrics` pipeline:

```yaml
service:
  pipelines:
    metrics:
      receivers: [host_metrics, otlp]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [signalfx]
```

---

## Validate Config Before Restarting

```bash
# Linux — if otelcol binary supports validate
sudo /usr/lib/splunk-otel-collector/bin/otelcol validate --config /etc/otel/collector/agent_config.yaml
```

```powershell
# Windows
& "C:\Program Files\Splunk\OpenTelemetry Collector\otelcol.exe" validate --config "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
```

> ⚠️ Only ever have **one** `metrics:`, one `logs:`, and one `traces:` key under `service.pipelines`. Adding a second one with the same name is invalid YAML and will crash the service on restart — merge new receivers into the existing pipeline instead.

---

## Troubleshooting

| Issue | Check |
|---|---|
| Service won't restart after edit | Check for duplicate top-level keys, bad indentation, or missing colons — restore `.bak` and re-edit |
| No CPU/memory data | Confirm `host_metrics` is listed under the `metrics` pipeline's `receivers:` |
| No disk data | Confirm `disk`/`filesystem` scrapers aren't excluded by a mount/fs filter |
| No network data | Confirm `network` scraper is enabled; check firewall isn't blocking outbound to `ingest.<REALM>.signalfx.com:443` |
| No APM traffic | Confirm the app is instrumented and sending to `localhost:4317`/`4318`, not just host-level network metrics |

---

## Reference

- Host metrics receiver docs: https://docs.splunk.com/observability/en/gdi/opentelemetry/components/host-metrics-receiver.html

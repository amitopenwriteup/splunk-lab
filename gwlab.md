# Lab: Setting Up the Splunk OTel Collector in Gateway Mode (Single-VM Version)

**Objective:** By the end of this workshop, you will run two Collector instances side-by-side on **one** Linux VM: an **agent**-mode instance and a **gateway**-mode instance. The agent instance forwards data over localhost to the gateway instance, which forwards it on to Splunk Observability Cloud. This mirrors a real two-VM topology, just collapsed onto one host using distinct ports and systemd units.

**Estimated time:** 45 minutes

**Prerequisites:** Completion of `lab-otel-collector-linux-part1.md` (you should already understand agent mode, access tokens, and realms)

**Environment:** One Linux VM (Ubuntu/Debian or RHEL/CentOS family), sudo access, internet egress on port 443

---

## Why Gateway Mode?

In **agent mode**, the Collector talks directly to Splunk Observability Cloud. That's fine for small setups, but at scale it means every host needs outbound internet access and its own access token management.

In **gateway mode**, one or more Collectors sit between your fleet of agents and Splunk Observability Cloud. Use gateway mode when you want to:

- Configure a larger buffer
- Configure an increased wait interval for retry attempts
- Limit the number of egress points that need internet access
- Consolidate access token management in one place

**Topology for this lab (single VM):**

```
[agent instance, localhost] ---> [gateway instance, localhost] ---> Splunk Observability Cloud
      (default ports 4317/4318)       (alternate ports 14317/14318)
```

Since both instances run on the same host, they're distinguished by port and by systemd unit name rather than by separate machines. The Linux installer script only ever creates one systemd unit (`splunk-otel-collector`, running the `/usr/bin/otelcol` binary), and it installs both `agent_config.yaml` and `gateway_config.yaml` regardless of which `--mode` you pass — the mode flag just controls which file `SPLUNK_CONFIG` points at. So rather than re-running the installer, this lab reuses the binary and config files Part 1 already put on disk and adds a second, hand-written systemd unit for the gateway instance.

---

## Workshop Prerequisites

| Item | Where to find it |
|---|---|
| Splunk Access Token (INGEST scope) | Reuse the one from Part 1, or create a new one via Settings → Access Tokens |
| Realm | Same realm identified in Part 1 |
| VM | The single VM from Part 1, already running agent mode |

Set your shell variables:

```bash
export SPLUNK_REALM="<your-realm>"
export SPLUNK_ACCESS_TOKEN="<your-access-token>"
```

---

## Exercise 1 — Stand Up a Second (Gateway) Instance

### Task
Reuse the Collector binary and config files Part 1 already installed, and add a second systemd unit so a gateway instance can run alongside the existing agent instance on this VM.

### Steps

Part 1's installer already placed the binary at `/usr/bin/otelcol` and dropped both `agent_config.yaml` and `gateway_config.yaml` into `/etc/otel/collector/`. Confirm both are present:

```bash
ls -l /usr/bin/otelcol
ls -l /etc/otel/collector/
```

Copy the gateway config to its own file (so later edits don't affect the shipped default), and create a separate environment file for the gateway instance:

```bash
sudo cp /etc/otel/collector/gateway_config.yaml /etc/otel/collector/gateway_config_local.yaml
sudo tee /etc/otel/collector/gateway-instance.conf > /dev/null <<EOF
SPLUNK_CONFIG=/etc/otel/collector/gateway_config_local.yaml
SPLUNK_ACCESS_TOKEN=${SPLUNK_ACCESS_TOKEN}
SPLUNK_REALM=${SPLUNK_REALM}
SPLUNK_MEMORY_TOTAL_MIB=256
EOF
```

Create a dedicated systemd unit for the gateway instance, modeled on the same `ExecStart=/usr/bin/otelcol $OTELCOL_OPTIONS` pattern the installer's own unit uses:

```bash
sudo tee /etc/systemd/system/splunk-otel-collector-gateway.service > /dev/null <<'EOF'
[Unit]
Description=Splunk OTel Collector (gateway instance)
After=network.target

[Service]
EnvironmentFile=/etc/otel/collector/gateway-instance.conf
ExecStart=/usr/bin/otelcol $OTELCOL_OPTIONS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now splunk-otel-collector-gateway
```

> **Note:** `SPLUNK_CONFIG` in the environment file tells `otelcol` which YAML to load, the same mechanism the installer's own unit uses to distinguish agent vs. gateway mode. This is why Part 1's existing `splunk-otel-collector` service and this new `splunk-otel-collector-gateway` service can run the same binary with two different configs at once.

### Validate

```bash
sudo systemctl status splunk-otel-collector-gateway
```

**Expected result:** `active (running)`.

---

## Exercise 2 — Inspect the Gateway Configuration

### Task
Locate and review the gateway config, and compare it against the agent config from Part 1.

### Steps

```bash
ls -l /etc/otel/collector/
cat /etc/otel/collector/gateway_config_local.yaml
cat /etc/otel/collector/gateway-instance.conf
```

### Checkpoint questions
- Which receiver is configured to accept incoming data from the agent instance? (Look for `otlp`)
- Which exporter sends data onward to Splunk Observability Cloud? (Look for `sapm`, `signalfx`)
- Does `SPLUNK_CONFIG` in `gateway-instance.conf` point at `gateway_config_local.yaml`?

> **Tip:** You can switch either instance between modes at any time by changing the `SPLUNK_CONFIG` path in its environment file to point at `agent_config.yaml` or `gateway_config_local.yaml`, then restarting the corresponding service. You don't need to reinstall.

---

## Exercise 3 — Move the Gateway Instance to Alternate Ports

### Task
The agent instance from Part 1 is already running with its default `agent_config.yaml`, which includes an `otlp` receiver bound to `4317`/`4318`. Since the gateway instance runs on the same VM, it can't bind those same ports. Move the gateway's OTLP receiver to `14317`/`14318` instead.

### Steps

Check what's currently bound on the default ports (this should be the agent instance):

```bash
sudo ss -tlnp | grep -E '4317|4318'
```

Edit the gateway's local config and change its `otlp` receiver endpoints:

```bash
sudo nano /etc/otel/collector/gateway_config_local.yaml
```

```yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:14317
      http:
        endpoint: 0.0.0.0:14318
```

Restart the gateway instance and confirm it's now listening on the new ports:

```bash
sudo systemctl restart splunk-otel-collector-gateway
sudo ss -tlnp | grep -E '14317|14318'
```

**Expected result:** `14317` (OTLP gRPC) and/or `14318` (OTLP HTTP) are bound by the `otelcol` process belonging to `splunk-otel-collector-gateway`, while `4317`/`4318` remain owned by the original agent instance.

---

## Exercise 4 — Point the Agent Instance at the Gateway (via localhost)

### Task
Reconfigure the existing agent-mode Collector (from Part 1) to forward data to the gateway instance on `localhost:14317` instead of sending directly to Splunk Observability Cloud.

### Steps

Back up the existing config, then edit it:

```bash
sudo cp /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.yaml.bak
sudo nano /etc/otel/collector/agent_config.yaml
```

Add or update the `exporters` and `service.pipelines` sections so metrics are exported via `otlp` to the gateway instance on the same host:

```yaml
exporters:
  otlp:
    endpoint: "localhost:14317"
    tls:
      insecure: true

service:
  pipelines:
    metrics:
      receivers: [hostmetrics]
      processors: [batch, resourcedetection, memory_limiter]
      exporters: [otlp]
```

> **Note:** This lab uses `insecure: true` for simplicity, and `localhost:14317` since both instances run on the same VM and the gateway's OTLP receiver was moved to port `14317` in Exercise 3. In a real multi-VM deployment, you'd use the gateway VM's IP address on the default `4317` port and configure TLS between agent and gateway.

Restart the agent Collector (this is still the original `splunk-otel-collector` service from Part 1):

```bash
sudo systemctl restart splunk-otel-collector
```

### Validate

```bash
sudo systemctl status splunk-otel-collector
sudo journalctl -u splunk-otel-collector -f --since "2 minutes ago"
```

Look for successful export log lines with no repeated `errors`/`dropped` entries.

---

## Exercise 5 — Confirm End-to-End Data Flow

### Task
Verify metrics travel agent instance → gateway instance → Splunk Observability Cloud, all on the one VM.

### Steps

Tail the gateway instance's logs to confirm it's receiving and forwarding data:

```bash
sudo journalctl -u splunk-otel-collector-gateway -f --since "5 minutes ago"
```

### Validate in the UI
1. Log in to Splunk Observability Cloud.
2. Go to **Infrastructure → Hosts**.
3. Search for the VM's hostname (`hostname` command output).
4. Confirm live CPU/memory graphs still appear — data is now flowing through the local gateway instance rather than directly from the agent instance.

---

## Workshop Checkpoint

| Component | Status |
|---|---|
| Gateway instance running as its own systemd unit (`splunk-otel-collector-gateway`) | Done |
| Gateway config (`gateway_config_local.yaml`) reviewed and moved to ports `14317`/`14318` | Done |
| Agent instance reconfigured to export to `localhost:14317` | Done |
| End-to-end data flow confirmed in Splunk Observability Cloud UI | Done |

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Agent logs show connection refused to `localhost:14317` | Gateway service not running, or the port change in Exercise 3 wasn't applied | `sudo systemctl status splunk-otel-collector-gateway`; re-check `sudo ss -tlnp \| grep 14317` |
| Gateway logs show no incoming data | Agent config not restarted, or exporter misconfigured | `sudo systemctl restart splunk-otel-collector`; re-check YAML indentation |
| `splunk-otel-collector-gateway` fails to start with an address-in-use error | Gateway config still points at the default `4317`/`4318`, which the agent instance already owns | Re-check `gateway_config_local.yaml` uses `14317`/`14318`, then `sudo systemctl restart splunk-otel-collector-gateway` |
| Host no longer appears in UI at all | Both `signalfx` (direct) and `otlp` (to gateway) exporters removed/misconfigured on the agent instance | Confirm `service.pipelines.metrics.exporters` includes `otlp` and the gateway is exporting via `signalfx`/`sapm` |

---

## Next Steps

- When you have more than one physical/virtual host available, repeat Exercise 4 pointing multiple agents at the same gateway instance instead of using `localhost`.
- Explore consolidating access token management so only the gateway instance holds `SPLUNK_ACCESS_TOKEN`.
- Revisit `lab-otel-collector-linux-part2.md` to layer logs, traces/APM, tagging, and alerting on top of this topology.

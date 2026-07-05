# Final Minimal Setup: App Container → Existing Host Collector

## Goal
Your app runs in Docker. The Splunk OTel Collector already runs as a systemd service on the Rocky Linux host. Get app telemetry flowing with the **least possible change**.

---

## Step 1 — Verify the collector already accepts container traffic (no edit yet)

```bash
sudo grep -A 5 "otlp:" /etc/otel/collector/agent_config.yaml
```

**Expected (no change needed):**
```yaml
otlp:
  protocols:
    grpc:
      endpoint: 0.0.0.0:4317
    http:
      endpoint: 0.0.0.0:4318
```

**If you instead see `localhost:4317` or `127.0.0.1:4317`** — this is the *only* case requiring a conf edit:
```bash
sudo sed -i 's/127.0.0.1:4317/0.0.0.0:4317/; s/localhost:4317/0.0.0.0:4317/' /etc/otel/collector/agent_config.yaml
sudo systemctl restart splunk-otel-collector
```

## Step 2 — Confirm firewall isn't blocking the port

```bash
sudo firewall-cmd --list-ports
```
If `4317/tcp` isn't listed:
```bash
sudo firewall-cmd --permanent --add-port=4317/tcp
sudo firewall-cmd --reload
```

## Step 3 — Run your app container pointing at the host collector

```bash
docker run -d --name my-app \
  --add-host=host.docker.internal:host-gateway \
  -e OTEL_EXPORTER_OTLP_ENDPOINT=http://host.docker.internal:4317 \
  -e OTEL_SERVICE_NAME=my-app \
  -p 8080:8080 \
  my-app-image:latest
```

No collector config edit required if Step 1 already showed `0.0.0.0`.

---

## Optional Add-on — Container CPU/Mem/Network Stats

Only needed if you also want infra-level container metrics (this **does** require editing `agent_config.yaml`, since `docker_stats` isn't in the default config):

```bash
sudo vi /etc/otel/collector/agent_config.yaml
```
Add:
```yaml
receivers:
  docker_stats:
    endpoint: unix:///var/run/docker.sock
    collection_interval: 10s

service:
  pipelines:
    metrics:
      receivers: [hostmetrics, docker_stats]   # add docker_stats here
```
Grant socket access and restart:
```bash
sudo usermod -aG docker splunk-otel-collector
sudo systemctl restart splunk-otel-collector
```

---

## Cross-Verification Steps

### 1. Collector is healthy
```bash
sudo systemctl status splunk-otel-collector
```
Expect: `Active: active (running)`

### 2. Collector is receiving data from the app
```bash
sudo journalctl -u splunk-otel-collector -f
```
Look for OTLP trace/metric export activity, no `dropped`/`error`/`context deadline exceeded` lines. `Ctrl+C` to stop.

### 3. App can actually reach the collector (network-level check)
From inside the app container:
```bash
docker exec -it my-app curl -v http://host.docker.internal:4317
```
A connection response (even an error page, since 4317 is gRPC) confirms reachability. A `Connection refused` or timeout means Step 1/2 wasn't applied correctly.

### 4. Confirm in Splunk Observability Cloud UI
| Check | Where |
|---|---|
| Host metrics | Infrastructure → Hosts → search hostname |
| App traces | APM → search `my-app` (service name from `OTEL_SERVICE_NAME`) |
| Container stats (if added) | Infrastructure → Containers, or Metric Finder → `docker.container.*` |

### 5. If nothing shows up after 2–3 minutes
```bash
sudo journalctl -u splunk-otel-collector --since "5 min ago" | grep -i error
docker logs my-app | grep -i otel
```
Check both sides — collector-side export errors (bad token/realm) vs. app-side connection errors (endpoint unreachable).

---

## Summary Table

| Requirement | Conf edit needed? |
|---|---|
| App sends traces/metrics to existing collector | ❌ No (only if `otlp` was bound to localhost) |
| Container CPU/mem/network stats | ✅ Yes — add `docker_stats` |
| Firewall port open | Check once, no recurring change |

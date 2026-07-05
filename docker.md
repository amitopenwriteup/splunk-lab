# Hands-On Lab: Monitoring Docker Containers with Splunk Observability Cloud

**Based on:** [Splunk Docs — Docker Containers Integration](https://help.splunk.com/en/splunk-observability-cloud/manage-data/available-data-sources/supported-integrations-in-splunk-observability-cloud/applications-hosts-and-servers/docker-containers)

**Objective:** Configure the Splunk Distribution of the OpenTelemetry Collector (already running on your Linux host) to collect real Docker container metrics — CPU, memory, network, block I/O — using the built-in `docker-container-stats` Smart Agent monitor, and confirm the data lands in Splunk Observability Cloud.

**Prerequisites:**
- Splunk Distribution of the OpenTelemetry Collector already installed and running on the host (Linux, Windows, or Kubernetes — this lab covers Linux)
- Docker installed and running on the same host
- At least one running container (any image — nginx, your app, anything)
- Sudo/root access on the host

---

## Easy Explain: What This Integration Actually Does

Unlike app-level tracing (which needs your *application* to speak OTLP), this integration works at the **Docker Engine level**. The collector talks directly to the **Docker API** (the same API `docker stats` uses) and pulls CPU, memory, network, and disk I/O numbers for every container running on the host — with **zero changes required inside your containers or app code**.

> **Key limitation to know upfront:** this monitor does **not** currently support CPU share/quota metrics. If you need those, you'd need a different collection method — out of scope for this lab.

**Use case:** A platform team runs 40 containers across a handful of hosts and just wants a dashboard showing "which container is eating memory right now" — without touching any application, redeploying anything, or waiting for developers to add instrumentation. This integration is built exactly for that.

---

## Step 1 — Confirm the Collector Can Reach the Docker Socket

The Smart Agent monitor talks to Docker over its Unix socket (`/var/run/docker.sock` by default). The collector runs as the `splunk-otel-collector` user, which normally does **not** have permission to read that socket.

```bash
ls -l /var/run/docker.sock
```

You'll typically see it owned by `root:docker`. Add the collector's user to the `docker` group so it can access the socket:

```bash
sudo usermod -aG docker splunk-otel-collector
```

**Restart the collector after this** (group membership changes don't apply to already-running processes):

```bash
sudo systemctl restart splunk-otel-collector
```

> **Easy explain:** This is the exact same reason you sometimes have to run `docker` commands with `sudo` on a fresh Linux install — until your own user is in the `docker` group, the socket says "no." Same rule applies to the collector's service account.

---

## Step 2 — Add the Smart Agent Receiver to the Collector Config

Open the collector's config file:

```bash
sudo vi /etc/otel/collector/agent_config.yaml
```

Under the top-level `receivers:` section, add:

```yaml
receivers:
  smartagent/docker-container-stats:
    type: docker-container-stats
    dockerURL: unix:///var/run/docker.sock
```

**Easy explain of each line:**

| Line | What it means |
|---|---|
| `smartagent/docker-container-stats` | The receiver's name — `smartagent/` is a required prefix for any Smart Agent–style monitor |
| `type: docker-container-stats` | Tells the collector which built-in monitor logic to run |
| `dockerURL` | Where to find the Docker API — default is the local Unix socket. Only change this if Docker is remote, or on Windows (see Step 6) |

---

## Step 3 — Wire the Receiver into the Metrics Pipeline

Defining a receiver isn't enough — like you saw with the `otlp` receiver earlier, it must also be listed under `service.pipelines.metrics.receivers`, or the collector will never actually run it.

```bash
sudo grep -A 10 "^service:" /etc/otel/collector/agent_config.yaml
```

Find your existing `metrics:` pipeline (it likely already has `host_metrics` and `otlp` if you set those up earlier) and add the new receiver to the list:

```yaml
service:
  pipelines:
    metrics:
      receivers: [host_metrics, otlp, smartagent/docker-container-stats]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [signalfx]
```

> **Don't create a brand-new `metrics:` pipeline** — add to the existing one. Multiple metrics pipelines is valid YAML but usually not what you want; it just adds unnecessary complexity for this lab.

---

## Step 4 — Restart and Verify the Collector Picked It Up

```bash
sudo systemctl restart splunk-otel-collector
sudo systemctl status splunk-otel-collector --no-pager
```

Check the logs for any Docker-related startup errors:

```bash
sudo journalctl -u splunk-otel-collector --since "2 min ago" --no-pager | grep -iE "docker|smartagent|error"
```

**What a healthy startup looks like:** no `permission denied` or `Error initializing Docker client` lines. If you see either, go back to Step 1 — it almost always means the group membership didn't take effect (double check you restarted the collector *after* running `usermod`).

---

## Step 5 — Confirm Metrics Are Actually Flowing

**A. Generate some load so there's something to see:**

```bash
docker stats --no-stream
```

This confirms Docker itself is reporting stats for your running containers (sanity check that the API works at all, independent of the collector).

**B. Check in Splunk Observability Cloud:**

| Where | What to look for |
|---|---|
| **Metric Finder** | Search `container.cpu`, `container.memory`, `container.network`, `container.blkio` |
| **Infrastructure → Containers** | Your container names should appear as entities |
| **Navigator** | Containers should show up grouped under your host |

**C. If nothing shows up after 2–3 minutes**, check both ends:

```bash
# Collector side — is the docker monitor emitting anything?
sudo journalctl -u splunk-otel-collector --since "5 min ago" | grep -i "docker\|dropped\|error"

# Confirm the collector process is actually in the docker group now
groups splunk-otel-collector
id splunk-otel-collector
```

If `groups` doesn't show `docker` in the output, the `usermod` didn't apply, or you're checking before a fresh login/restart took effect.

---

## Step 6 — Windows Note (Reference Only — Skip on Linux)

If this were a Windows host instead, the socket path is different:

```yaml
dockerURL: npipe:////.//pipe//docker_engine
```

If you ever see this error on Windows:
```
Error: Error initializing Docker client: protocol not available
```
It means `dockerURL` is still pointing at the Linux Unix socket path — swap it for the `npipe://` path above.

---

## Step 7 (Optional) — Tune What Gets Collected

The monitor supports extra metric categories that are **off by default** (to control data volume/cost). Add any of these under the receiver if you need deeper visibility:

```yaml
receivers:
  smartagent/docker-container-stats:
    type: docker-container-stats
    dockerURL: unix:///var/run/docker.sock
    enableExtraCPUMetrics: true
    enableExtraMemoryMetrics: true
    enableExtraNetworkMetrics: true
    enableExtraBlockIOMetrics: true
```

| Option | Easy explain |
|---|---|
| `enableExtraCPUMetrics` | More granular CPU breakdown per container |
| `enableExtraMemoryMetrics` | Deeper memory metric detail (cache, RSS, etc.) |
| `enableExtraNetworkMetrics` | Per-interface network stats instead of just totals |
| `enableExtraBlockIOMetrics` | Disk read/write detail per container |
| `excludedImages` | Filter out noisy containers by image name (supports literals, globs, regex) |
| `labelsToDimensions` | Map a Docker label (e.g. `io.kubernetes.container.name`) to a Splunk dimension name, so you can filter/group by it in the UI |

**Use case for `excludedImages`:** You run a handful of short-lived CI/test containers on the same host as production services. Excluding their image pattern keeps your container dashboards from being cluttered with noise that isn't operationally relevant.

Restart the collector after any config change:

```bash
sudo systemctl restart splunk-otel-collector
```

---

## Lab Completion Checklist

- [ ] `splunk-otel-collector` user added to the `docker` group
- [ ] Collector restarted after group change
- [ ] `smartagent/docker-container-stats` receiver added to `agent_config.yaml`
- [ ] Receiver added to `service.pipelines.metrics.receivers`
- [ ] Collector restarted again after config edit
- [ ] No `permission denied` / `Error initializing Docker client` errors in logs
- [ ] Container metrics visible in **Metric Finder** and **Infrastructure → Containers**

---

## Summary Table

| Requirement | Config change needed? |
|---|---|
| Collector can read Docker socket | Yes — `usermod -aG docker splunk-otel-collector` + restart |
| Receiver defined | Yes — `smartagent/docker-container-stats` block |
| Receiver active in pipeline | Yes — add to `pipelines.metrics.receivers` |
| App-level code changes | None — this integration is host/Docker-API level, not app-instrumentation level |
| CPU share/quota metrics | Not supported by this monitor |

---

## Troubleshooting Reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `Error initializing Docker client: protocol not available` | Wrong `dockerURL` for the OS (Windows using Unix socket path) | Switch to `npipe://` path (Step 6) |
| No container metrics in UI after restart | Collector user not in `docker` group, or restarted before group change applied | Re-run `usermod`, confirm with `id splunk-otel-collector`, restart again |
| Receiver defined but nothing happens | Receiver not added to `pipelines.metrics.receivers` | Recheck Step 3 |
| Too much data / noisy containers | No filtering configured | Add `excludedImages` (Step 7) |

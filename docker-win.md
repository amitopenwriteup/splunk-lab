# Hands-On Lab: Monitoring Docker Desktop (WSL2) Containers with Splunk Observability Cloud

**Based on:** [Splunk Docs — Docker Containers Integration](https://help.splunk.com/en/splunk-observability-cloud/manage-data/available-data-sources/supported-integrations-in-splunk-observability-cloud/applications-hosts-and-servers/docker-containers)

**Objective:** Configure the Splunk Distribution of the OpenTelemetry Collector to collect real Docker container metrics — CPU, memory, network, block I/O — from **Docker Desktop running on Windows with the WSL2 backend**, using the built-in `docker-container-stats` Smart Agent monitor.

**Prerequisites:**
- Windows 10/11 with WSL2 enabled (`wsl --status` shows WSL 2 as default)
- Docker Desktop installed, running, and set to use the **WSL2 backend** (Settings → General → "Use the WSL 2 based engine")
- Splunk Distribution of the OpenTelemetry Collector installed — either as a **Windows service** or **inside a WSL2 distro** (this lab covers both paths; pick one)
- At least one running container (any image — nginx, your app, anything)
- Administrator access on Windows (and sudo inside WSL if you choose that path)

---

## Easy Explain: What's Different on Windows + WSL2

The integration logic is identical to Linux — the collector talks to the **Docker Engine API**, not your application, so there's still **zero code changes** inside containers. What changes is *how the collector reaches that API*, because Docker Desktop's engine actually runs inside a hidden WSL2 utility VM, and it exposes itself two different ways depending on where your collector lives:

| Collector location | How it reaches Docker Desktop |
|---|---|
| **Windows host** (installed as a Windows service) | Named pipe: `npipe:////./pipe/docker_engine` |
| **Inside a WSL2 distro** (e.g., Ubuntu) with WSL integration enabled | Unix socket: `unix:///var/run/docker.sock` (Docker Desktop bind-mounts it into the distro) |

> **Key limitation carried over from Linux:** this monitor still does **not** support CPU share/quota metrics. Same limitation, different OS.

Pick the path that matches how you actually installed the collector. Most Windows-first users run the collector as a Windows service (Path A). If you're doing everything inside WSL for convenience, use Path B.

---

## Step 1 — Confirm Docker Desktop's Engine Is Reachable

**Check Docker Desktop itself is running and WSL2-backed:**

```powershell
docker version
wsl --list --verbose
```

You should see Docker Desktop's own WSL distros (`docker-desktop` and `docker-desktop-data`) listed as running.

### Path A — Collector runs as a Windows service

Docker Desktop exposes its engine to Windows processes via a named pipe — there's no Unix socket to chase permissions on. As long as **"Expose daemon on tcp://localhost:2375 without TLS"** is off (default, and you should leave it off) you don't need to touch this; the named pipe works out of the box for local Windows processes, including a Windows service. No group/permission step is needed here (unlike Linux's `docker` group).

Confirm the pipe exists:

```powershell
Get-ChildItem \\.\pipe\ | Select-String "docker_engine"
```

### Path B — Collector runs inside a WSL2 distro

Enable WSL integration for that distro so Docker Desktop bind-mounts the socket into it:

**Docker Desktop → Settings → Resources → WSL Integration** → toggle on for the distro your collector runs in (e.g., Ubuntu).

Then, from inside that WSL distro, confirm the socket is present:

```bash
ls -l /var/run/docker.sock
```

> **Easy explain:** On native Linux you add the collector's *service account* to the `docker` group to unlock the socket. Docker Desktop skips that whole dance — WSL integration does the equivalent wiring for you, and the named pipe on the Windows side needs no group at all.

---

## Step 2 — Add the Smart Agent Receiver to the Collector Config

### Path A — Windows service config

Open the config (default install path):

```powershell
notepad "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
```

Under `receivers:`, add:

```yaml
receivers:
  smartagent/docker-container-stats:
    type: docker-container-stats
    dockerURL: npipe:////./pipe/docker_engine
```

### Path B — WSL2 distro config

```bash
sudo vi /etc/otel/collector/agent_config.yaml
```

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
| `dockerURL` | Where to find the Docker API. `npipe://` for Windows-service collectors talking to Docker Desktop's named pipe; `unix://` for collectors running inside a WSL2 distro |

> **Common mistake:** using `unix:///var/run/docker.sock` from a Windows-service collector, or `npipe://` from a WSL-hosted collector. Each side only understands its own transport — mixing them produces the `protocol not available` error covered in the troubleshooting table below.

---

## Step 3 — Wire the Receiver into the Metrics Pipeline

Same rule as Linux: defining the receiver isn't enough — it must be listed under `service.pipelines.metrics.receivers`.

**Path A (PowerShell):**
```powershell
Select-String -Path "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml" -Pattern "^service:" -Context 0,10
```

**Path B (WSL):**
```bash
sudo grep -A 10 "^service:" /etc/otel/collector/agent_config.yaml
```

Find your existing `metrics:` pipeline (it likely already has `host_metrics` and `otlp` if you set those up earlier) and add the new receiver:

```yaml
service:
  pipelines:
    metrics:
      receivers: [host_metrics, otlp, smartagent/docker-container-stats]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [signalfx]
```

> **Don't create a brand-new `metrics:` pipeline** — add to the existing one, same as on Linux.

---

## Step 4 — Restart and Verify the Collector Picked It Up

**Path A — Windows service:**

```powershell
Restart-Service splunk-otel-collector
Get-Service splunk-otel-collector
```

Check recent logs for Docker-related errors:

```powershell
Get-Content "C:\ProgramData\Splunk\OpenTelemetry Collector\collector.log" -Tail 200 | Select-String -Pattern "docker|smartagent|error" -CaseSensitive:$false
```

**Path B — WSL2 distro:**

```bash
sudo systemctl restart splunk-otel-collector
sudo systemctl status splunk-otel-collector --no-pager
sudo journalctl -u splunk-otel-collector --since "2 min ago" --no-pager | grep -iE "docker|smartagent|error"
```

**What a healthy startup looks like:** no `permission denied`, `access is denied`, or `Error initializing Docker client` lines. If you see one, go back to Step 1 — for Path A, confirm Docker Desktop is actually running (the named pipe only exists while it is); for Path B, confirm WSL integration is toggled on for that distro and re-open your WSL terminal after enabling it.

---

## Step 5 — Confirm Metrics Are Actually Flowing

**A. Generate some load so there's something to see:**

```powershell
docker stats --no-stream
```

This works identically whether you run it from PowerShell or inside a WSL distro — it's the same Docker Desktop engine either way, so it's a good sanity check that the API itself is answering, independent of the collector.

**B. Check in Splunk Observability Cloud:**

| Where | What to look for |
|---|---|
| **Metric Finder** | Search `container.cpu`, `container.memory`, `container.network`, `container.blkio` |
| **Infrastructure → Containers** | Your container names should appear as entities |
| **Navigator** | Containers should show up grouped under your host |

**C. If nothing shows up after 2–3 minutes**, check both ends:

**Path A:**
```powershell
Get-Content "C:\ProgramData\Splunk\OpenTelemetry Collector\collector.log" -Tail 300 | Select-String -Pattern "docker|dropped|error" -CaseSensitive:$false
Test-Path \\.\pipe\docker_engine
```

**Path B:**
```bash
sudo journalctl -u splunk-otel-collector --since "5 min ago" | grep -i "docker\|dropped\|error"
wsl --list --verbose   # run from Windows, confirm docker-desktop distros are Running
```

If the pipe/socket check fails, Docker Desktop likely isn't running, or (Path B only) WSL integration for that distro isn't enabled — toggle it in Docker Desktop settings and restart the distro (`wsl --terminate <distro>` then reopen it).

---

## Step 6 — Cross-Reference: Native Linux Note (Reference Only)

If this were a native Linux host instead of Docker Desktop, the transport is a Unix socket owned by `root:docker`, and you'd need to add the collector's service account to the `docker` group:

```bash
sudo usermod -aG docker splunk-otel-collector
sudo systemctl restart splunk-otel-collector
```

```yaml
dockerURL: unix:///var/run/docker.sock
```

Docker Desktop's WSL2 setup replaces that group-permission step with either the named pipe (Path A, no permission step at all) or WSL integration toggling (Path B).

---

## Step 7 (Optional) — Tune What Gets Collected

Same options as Linux, off by default to control data volume/cost:

```yaml
receivers:
  smartagent/docker-container-stats:
    type: docker-container-stats
    dockerURL: npipe:////./pipe/docker_engine   # or unix:///var/run/docker.sock for Path B
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
| `labelsToDimensions` | Map a Docker label to a Splunk dimension name, so you can filter/group by it in the UI |

**Use case for `excludedImages`:** Docker Desktop dev boxes often run short-lived test containers alongside the ones you actually care about. Excluding their image pattern keeps your container dashboards clean.

Restart after any config change (Path A: `Restart-Service splunk-otel-collector`; Path B: `sudo systemctl restart splunk-otel-collector`).

---

## Lab Completion Checklist

- [ ] Docker Desktop confirmed running with WSL2 backend (`docker version`, `wsl --list --verbose`)
- [ ] Chosen a path: **A (Windows service + named pipe)** or **B (WSL2 distro + Unix socket)**
- [ ] Path A: named pipe confirmed reachable — or — Path B: WSL integration enabled for the distro and socket confirmed
- [ ] `smartagent/docker-container-stats` receiver added to `agent_config.yaml` with the correct `dockerURL` for your path
- [ ] Receiver added to `service.pipelines.metrics.receivers`
- [ ] Collector restarted after config edit
- [ ] No `access is denied` / `permission denied` / `Error initializing Docker client` errors in logs
- [ ] Container metrics visible in **Metric Finder** and **Infrastructure → Containers**

---

## Summary Table

| Requirement | Path A (Windows service) | Path B (WSL2 distro) |
|---|---|---|
| Transport | `npipe:////./pipe/docker_engine` | `unix:///var/run/docker.sock` |
| Permission step | None (named pipe works for local Windows processes by default) | Enable WSL Integration in Docker Desktop settings |
| Receiver defined | Yes — `smartagent/docker-container-stats` block | Yes — same block, different `dockerURL` |
| Receiver active in pipeline | Yes — add to `pipelines.metrics.receivers` | Yes — same |
| App-level code changes | None | None |
| CPU share/quota metrics | Not supported by this monitor | Not supported by this monitor |

---

## Troubleshooting Reference

| Symptom | Likely cause | Fix |
|---|---|---|
| `Error initializing Docker client: protocol not available` | Wrong `dockerURL` transport for where the collector runs (e.g., `unix://` used from a Windows-service collector, or vice versa) | Match transport to path: `npipe://` for Path A, `unix://` for Path B (Step 2) |
| `access is denied` opening the named pipe | Docker Desktop isn't running, or collector service isn't running under a user allowed to open it | Start Docker Desktop first; confirm with `Test-Path \\.\pipe\docker_engine` |
| Socket missing inside WSL distro | WSL Integration not enabled for that distro | Docker Desktop → Settings → Resources → WSL Integration → enable, then restart the distro |
| No container metrics in UI after restart | Receiver misconfigured, or collector restarted before Docker Desktop/WSL integration change applied | Recheck Step 1 for your path, then re-restart the collector |
| Receiver defined but nothing happens | Receiver not added to `pipelines.metrics.receivers` | Recheck Step 3 |
| Too much data / noisy containers | No filtering configured | Add `excludedImages` (Step 7) |

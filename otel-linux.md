# Lab: Installing the Splunk OTel Collector on Rocky Linux (Setup & Host Metrics)

**Objective:** By the end of this lab, you will have the Splunk OTel Collector installed and running on a Rocky Linux machine, sending host metrics to Splunk Observability Cloud.

**Estimated time:** 15–20 minutes

**Environment:** Rocky Linux 8 or 9 (x86_64), root or sudo access, `curl` installed, internet egress on port 443

---

## Lab Prerequisites

Before starting, gather:

| Item | Where to find it |
|---|---|
| Splunk Access Token | Settings → Access Tokens (Splunk Observability Cloud UI) |
| Realm | In your org URL: `https://app.<REALM>.signalfx.com` |
| Rocky Linux machine | x86_64, sudo/root access |

### Creating the Access Token

1. In Splunk Observability Cloud, go to **Settings → Access Tokens → New Token**.
2. **Name & Scope** step:
   - **Name**: e.g. `otel-collector-rocky-vm`
   - **Authorization and capability scope**: check **INGEST token** only.
     - Do **not** check **API token with roles** — that scope is for managing the platform (dashboards, detectors) via API, not for sending data from a collector.
     - **RUM token** is only for browser/mobile Real User Monitoring — not needed here.
   - **Description** (optional): e.g. `Used by splunk-otel-collector.sh on Rocky Linux lab VM`
3. Click **Next**, set an **Expiration** (or leave as non-expiring for the lab).
4. Click **Create**/**Finish** and copy the token value immediately — it is shown only once.

### Finding Your Realm

The **realm** is the region/cluster your Splunk Observability Cloud org lives in. Find it using any of these:

- **Browser URL** — when logged in, check the address bar:
  ```
  https://app.<REALM>.signalfx.com
  ```
  Examples: `https://app.us1.signalfx.com` → realm is `us1`; `https://app.eu0.signalfx.com` → realm is `eu0`

- **Settings → Organization Overview** (or **Settings → Access Tokens**) — the realm is often listed alongside your org details.

- **Ingest/API endpoint** — if you were given an endpoint like `ingest.us2.signalfx.com`, the realm is the part between `ingest.` and `.signalfx.com` (here, `us2`).

Common realms: `us0`, `us1`, `us2`, `eu0`, `eu1`, `au0`, `jp0`.

Set these as shell variables for convenience throughout the lab (in a terminal with `sudo` access):

```bash
export SPLUNK_REALM="<your-realm>"
export SPLUNK_ACCESS_TOKEN="<your-access-token>"
```

---

## Exercise 1 — Install the Collector

### Task
Install the Splunk OTel Collector as a systemd service in agent mode.

### Step 0 — Confirm system requirements

```bash
cat /etc/rocky-release
uname -m
```

Confirm you're on Rocky Linux 8/9 and `x86_64` architecture (the install script also supports `aarch64`).

### Step 1 — Download and run the installer

> **Note:** As with the Windows script, downloading the installer to a file first and inspecting it before execution is good practice — especially on production or shared machines. Piping `curl` directly into `sh` works for a lab but skips that review step; use the two-step method below if you want to inspect the script first.

**Two-step method (download, then run):**

```bash
curl -O https://dl.signalfx.com/splunk-otel-collector.sh
sudo sh splunk-otel-collector.sh \
  --realm "$SPLUNK_REALM" \
  -- "$SPLUNK_ACCESS_TOKEN" \
  --mode agent
```

**Optional — set the deployment environment tag at install time** (otherwise the host shows as `environment: unknown` until tagged manually later):

```bash
sudo sh splunk-otel-collector.sh \
  --realm "$SPLUNK_REALM" \
  --deployment-environment lab \
  -- "$SPLUNK_ACCESS_TOKEN" \
  --mode agent
```

The installer will:
- Add the Splunk package repo (`.rpm` based, via `dnf`/`yum`)
- Install the `splunk-otel-collector` package
- Write the default configuration
- Enable and start the `splunk-otel-collector` systemd service

You'll see output ending with something like:

```
splunk-otel-collector.service: Started
```

This is expected — the installer finishes by starting the systemd service automatically (no separate start command needed, unlike a manual RPM install).

### Validate

```bash
sudo systemctl status splunk-otel-collector
```

**Expected result:** `Active: active (running)`.

If SELinux is enforcing and you hit permission-denied errors starting the service, check:

```bash
sudo sestatus
sudo ausearch -m avc -ts recent
```

Most environments do not require SELinux policy changes for the collector, but locked-down enterprise images occasionally do — flag this to your admin if `ausearch` shows denials tied to `otelcol`.

---

## Exercise 2 — Inspect the Default Configuration

### Task
Locate and review the collector's config files.

### Steps

```bash
ls -la /etc/otel/collector/
sudo cat /etc/otel/collector/agent_config.yaml
 sudo cat /etc/systemd/system/splunk-otel-collector.service.d/service-owner.conf

```

### Checkpoint questions
- Which receivers are enabled by default? (Look for `hostmetrics`, `otlp`, `fluent_forward`)
- Which exporter sends data to Splunk Observability Cloud? (Look for `sapm`, `signalfx`)
- Where are your realm and access token stored so the service can authenticate? (Look in `/etc/otel/collector/splunk-otel-collector.conf` — an environment file referenced by the systemd unit)

```bash
sudo cat /etc/otel/collector/splunk-otel-collector.conf
```

---

## Exercise 3 — Verify Host Metrics Are Flowing

### Task
Confirm CPU, memory, disk, and network metrics are being collected and sent.

### Steps

```bash
sudo journalctl -u splunk-otel-collector -f
```

Look for log lines indicating successful exports (no repeated `error`/`dropped`/`context deadline exceeded` entries). Press `Ctrl+C` to stop following.

If you need to restart the service after a config change:

```bash
sudo systemctl restart splunk-otel-collector
sudo systemctl status splunk-otel-collector
```

### Validate in the UI
1. Log in to Splunk Observability Cloud.
2. Go to **Infrastructure → Hosts**.
3. Search for your machine's hostname (run `hostname` in the terminal to confirm it).
4. Confirm live CPU/memory graphs appear.

---

## Lab Checkpoint

| Component | Status |
|---|---|
| Access token created (INGEST scope) | ✅ |
| Realm identified | ✅ |
| OTel Collector installed & running as a systemd service | ✅ |
| Host metrics (CPU, memory, disk, network) visible in UI | ✅ |

**Next:** Enable log collection (`fluent_forward`/journald), add custom metrics, set up trace collection for APM, tag the host, and create an alert — same follow-on exercises as the Windows lab, just via `agent_config.yaml` and `systemctl` instead of PowerShell.

---

## Rocky Linux vs. Windows: Quick Reference

| Concept | Rocky Linux | Windows 10 |
|---|---|---|
| Install script | `splunk-otel-collector.sh` | `splunk-otel-collector.ps1` |
| Run installer as | root/sudo | Administrator (elevated PowerShell) |
| Service manager | `systemctl` (systemd) | `Get-Service` / `services.msc` |
| Service name | `splunk-otel-collector` | `splunk-otel-collector` |
| Config file location | `/etc/otel/collector/agent_config.yaml` | `C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml` |
| Binary location | `/usr/bin/otelcol` (via package) | `C:\Program Files\Splunk\OpenTelemetry Collector\` |
| Live log tail | `journalctl -u splunk-otel-collector -f` | `Get-Content ...\logs\otelcol.log -Tail 50 -Wait` |
| Common gotcha | SELinux denials on locked-down images | Editing config under Program Files instead of ProgramData |

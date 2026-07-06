# Lab Part 1: Installing the Splunk OTel Collector on Linux (Setup & Host Metrics)

**Objective:** By the end of this part, you will have the Splunk OTel Collector installed and running on a Linux VM, sending host metrics to Splunk Observability Cloud.

**Estimated time:** 30 minutes

**Environment:** Any Linux VM (Ubuntu/Debian or RHEL/CentOS family), sudo access, internet egress on port 443

**Continues in:** `lab-otel-collector-linux-part2.md` (Exercises 4–9: logs, custom metrics, traces/APM, tagging, alerting)

---

## Lab Prerequisites

Before starting, gather:

| Item | Where to find it |
|---|---|
| Splunk Access Token | Settings → Access Tokens (Splunk Observability Cloud UI) |
| Realm | In your org URL: `https://app.<REALM>.signalfx.com` |
| Linux VM | Ubuntu 20.04+/RHEL 8+ recommended |

### Creating the Access Token

1. In Splunk Observability Cloud, go to **Settings → Access Tokens → New Token**.
2. **Name & Scope** step:
   - **Name**: e.g. `otel-collector-linux-vm`
   - **Authorization and capability scope**: check **INGEST token** only.
     - Do **not** check **API token with roles** — that scope is for managing the platform (dashboards, detectors) via API, not for sending data from a collector.
     - **RUM token** is only for browser/mobile Real User Monitoring — not needed here.
   - **Description** (optional): e.g. `Used by splunk-otel-collector.sh on lab VM`
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

Set these as shell variables for convenience throughout the lab:

```bash
export SPLUNK_REALM="<your-realm>"
export SPLUNK_ACCESS_TOKEN="<your-access-token>"
```

---

## Exercise 1 — Install the Collector

### Task
Install the Splunk OTel Collector in agent mode.

### Steps

```bash
curl -sSL https://dl.observability.splunkcloud.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh
sudo sh /tmp/splunk-otel-collector.sh \
  --realm $SPLUNK_REALM \
  --mode agent \
  -- $SPLUNK_ACCESS_TOKEN
```

> **Note:** All flags (`--realm`, `--mode`, etc.) must come **before** the `--`. Everything after `--` is treated as a positional argument — the access token. `--mode agent` is also the script's default, so you can omit it if you prefer; it's included here for clarity.

### Validate

```bash
sudo systemctl status splunk-otel-collector
```

**Expected result:** `active (running)` in green.

---

## Exercise 2 — Inspect the Default Configuration

### Task
Locate and review the collector's config files.

### Steps

```bash
ls -l /etc/otel/collector/
cat /etc/otel/collector/agent_config.yaml
cat /etc/otel/collector/splunk-otel-collector.conf
```

### Checkpoint questions
- Which receivers are enabled by default? (Look for `hostmetrics`)
- Which exporter sends data to Splunk Observability Cloud? (Look for `sapm`, `signalfx`)

---

## Exercise 3 — Verify Host Metrics Are Flowing

### Task
Confirm CPU, memory, disk, and network metrics are being collected and sent.

### Steps

```bash
sudo journalctl -u splunk-otel-collector -f --since "5 minutes ago"
```

Look for log lines indicating successful exports (no repeated `errors`/`dropped` entries).

### Validate in the UI
1. Log in to Splunk Observability Cloud.
2. Go to **Infrastructure → Hosts**.
3. Search for your VM's hostname (`hostname` command output).
4. Confirm live CPU/memory graphs appear.

---

## Part 1 Checkpoint

| Component | Status |
|---|---|
| Access token created (INGEST scope) | ✅ |
| Realm identified | ✅ |
| OTel Collector installed & running | ✅ |
| Host metrics (CPU, memory, disk, network) visible in UI | ✅ |

**Next:** Continue to **Part 2** (`lab-otel-collector-linux-part2.md`) to enable log collection, add custom metric scrapers, set up trace collection for APM, tag the host, and create an alert.

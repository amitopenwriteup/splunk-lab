# Lab Part 1: Installing the Splunk OTel Collector on Windows 10 (Setup & Host Metrics)

**Objective:** By the end of this part, you will have the Splunk OTel Collector installed and running on a Windows 10 machine, sending host metrics to Splunk Observability Cloud.

**Estimated time:** 15–20 minutes

**Environment:** Windows 10 (64-bit), Administrator access, PowerShell 5.1+, internet egress on port 443

**Continues in:** `lab-otel-collector-windows-part2.md` (Exercises 4–9: logs, custom metrics, traces/APM, tagging, alerting)

---

## Lab Prerequisites

Before starting, gather:

| Item | Where to find it |
|---|---|
| Splunk Access Token | Settings → Access Tokens (Splunk Observability Cloud UI) |
| Realm | In your org URL: `https://app.<REALM>.signalfx.com` |
| Windows 10 machine | 64-bit, Administrator rights |

### Creating the Access Token

1. In Splunk Observability Cloud, go to **Settings → Access Tokens → New Token**.
2. **Name & Scope** step:
   - **Name**: e.g. `otel-collector-win10-vm`
   - **Authorization and capability scope**: check **INGEST token** only.
     - Do **not** check **API token with roles** — that scope is for managing the platform (dashboards, detectors) via API, not for sending data from a collector.
     - **RUM token** is only for browser/mobile Real User Monitoring — not needed here.
   - **Description** (optional): e.g. `Used by splunk-otel-collector.ps1 on Windows 10 lab VM`
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

Set these as PowerShell variables for convenience throughout the lab (in an **elevated PowerShell** session):

```powershell
$SplunkRealm = "<your-realm>"
$SplunkAccessToken = "<your-access-token>"
```

---

## Exercise 1 — Install the Collector

### Task
Install the Splunk OTel Collector as a Windows service in agent mode.

### Step 0 — Allow the script to run (Execution Policy)

By default, Windows blocks unsigned `.ps1` scripts from running. In your **elevated PowerShell** session, allow scripts for this session only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
```

- `-Scope Process` only affects this PowerShell window — it does not change your system-wide policy.
- `-Force` suppresses the confirmation prompt.

**If this still fails** (common on org-managed/locked-down machines with Group Policy), check what's enforced:

```powershell
Get-ExecutionPolicy -List
```

If `LocalMachine` shows a restrictive policy set by GPO, ask an admin to set `RemoteSigned` at that scope, or unblock the specific file after downloading it:

```powershell
Unblock-File -Path "$env:TEMP\splunk-otel-collector.ps1"
```

### Step 1 — Download and run the installer

> **Note:** Pasting a multi-line, backtick-continued command directly into the PowerShell console can sometimes mangle line breaks and throw a `CommandNotFoundException`. Downloading the script to a file first and then running it avoids this problem — use this method rather than the single-line web-download-and-execute pattern.

Open **PowerShell as Administrator**, then run:

```powershell
Invoke-WebRequest -Uri "https://dl.signalfx.com/splunk-otel-collector.ps1" -OutFile "$env:TEMP\splunk-otel-collector.ps1"

& "$env:TEMP\splunk-otel-collector.ps1" `
  -access_token $SplunkAccessToken `
  -realm $SplunkRealm `
  -mode "agent"
```

**Optional — set the deployment environment tag at install time** (otherwise the host shows as `environment: unknown` until tagged manually in Exercise 8 of Part 2):

```powershell
& "$env:TEMP\splunk-otel-collector.ps1" `
  -access_token $SplunkAccessToken `
  -realm $SplunkRealm `
  -mode "agent" `
  -deployment_environment "lab"
```

You'll see output like:

```
Deployment environment was not specified. Unless otherwise defined, will appear as 'unknown' in the UI.
Starting splunk-otel-collector service...
```

This is expected/informational, not an error — the installer is finishing up and starting the Windows service.

### Validate

```powershell
Get-Service splunk-otel-collector
```

**Expected result:** `Status` shows `Running`.

---

## Exercise 2 — Inspect the Default Configuration

### Task
Locate and review the collector's config files.

### Steps

```powershell
Get-ChildItem "C:\Program Files\Splunk\OpenTelemetry Collector\"
Get-Content "C:\Program Files\Splunk\OpenTelemetry Collector\agent_config.yaml"
Get-Content "C:\Program Files\Splunk\OpenTelemetry Collector\splunk-otel-collector.conf"
```

### Checkpoint questions
- Which receivers are enabled by default? (Look for `hostmetrics`, `windowsperfcounters`)
- Which exporter sends data to Splunk Observability Cloud? (Look for `sapm`, `signalfx`)

---

## Exercise 3 — Verify Host Metrics Are Flowing

### Task
Confirm CPU, memory, disk, and network metrics are being collected and sent.

### Steps

```powershell
Get-Content "C:\ProgramData\Splunk\OpenTelemetry Collector\logs\otelcol.log" -Tail 50 -Wait
```

Look for log lines indicating successful exports (no repeated `error`/`dropped` entries). Press `Ctrl+C` to stop tailing.

### Validate in the UI
1. Log in to Splunk Observability Cloud.
2. Go to **Infrastructure → Hosts**.
3. Search for your machine's hostname (run `hostname` in PowerShell to confirm it).
4. Confirm live CPU/memory graphs appear.

---

## Part 1 Checkpoint

| Component | Status |
|---|---|
| Access token created (INGEST scope) | ✅ |
| Realm identified | ✅ |
| OTel Collector installed & running as a Windows service | ✅ |
| Host metrics (CPU, memory, disk, network) visible in UI | ✅ |

**Next:** Continue to **Part 2** (`lab-otel-collector-windows-part2.md`) to enable Windows Event Log collection, add custom performance counters, set up trace collection for APM, tag the host, and create an alert.

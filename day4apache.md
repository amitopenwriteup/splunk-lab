# Lab: Apache, Tomcat — Windows

**Objective:** Configure metrics and APM trace collection for Apache HTTP Server, Apache Tomcat, IBM WebSphere Application Server (WAS), and Jenkins on Windows, and validate all four in Splunk Observability Cloud.

**Assumes:** The Splunk OTel Collector is already installed and running (`splunk-otel-collector` Windows service active). This lab only covers application-level instrumentation.

**Estimated time:** 40–50 minutes

**Config file:** `C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml`

---

## Lab Prerequisites

Open **PowerShell as Administrator**.

```powershell
Get-Service splunk-otel-collector
```

Confirm `Status` = `Running` before continuing.

Back up the config before making any changes:

```powershell
Copy-Item "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml" "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml.bak"
```

>  Throughout this lab, you will be **adding receivers to existing pipelines**, not creating new `metrics:`/`traces:` keys. YAML does not allow duplicate top-level keys — merge into the existing pipeline blocks instead.

---

## Part A — Apache HTTP Server

### Exercise 1 — Install Apache HTTP Server

### Task
Install Apache on Windows if it isn't already present.

### Steps

Apache Lounge's download URLs change with every release, and the site issues a `308 Permanent Redirect` that `Invoke-WebRequest` in Windows PowerShell 5.1 does not follow automatically. Use `curl.exe` (built into Windows 10/11) instead, which follows redirects correctly with `-L`.

Force TLS 1.2 for this session first (avoids handshake failures on older Windows builds):

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
```

Fetch the download page and resolve the current `.zip` link — case-insensitive and not pinned to a specific VS version, since Apache Lounge periodically moves the newest build to a new Visual Studio toolset (VS17, VS18, etc.) and capitalizes "Win64" inconsistently:

```powershell
curl.exe -L -s "https://www.apachelounge.com/download/" -o "$env:TEMP\apachelounge.html"
$html = Get-Content "$env:TEMP\apachelounge.html" -Raw
$matches = [regex]::Matches($html, 'href="([^"]*binaries/httpd-[^"]*[Ww]in64[^"]*\.zip)"', 'IgnoreCase')
$link = $matches[0].Groups[1].Value
$link
```

If `$link` is still empty, print all candidate links to see what's actually on the page:

```powershell
$matches | ForEach-Object { $_.Groups[1].Value }
```

The extracted link is often **relative** (e.g. `/download/VS18/binaries/httpd-...zip` with no domain) — `curl.exe` can't resolve that on its own, so prepend the base URL if needed:

```powershell
if ($link -notmatch '^https?://') {
    $link = "https://www.apachelounge.com" + $link
}
$link
```

Confirm `$link` now prints a **full** URL starting with `https://`, then download it (also via `curl.exe -L` so any further redirects are followed):

```powershell
curl.exe -L -s $link -o "$env:TEMP\httpd.zip"
```

**Verify the file actually downloaded before extracting** — this avoids a confusing `Expand-Archive` error if the download silently failed:

```powershell
Test-Path "$env:TEMP\httpd.zip"
```

If this returns `False`, do not proceed — troubleshoot the download first (or download manually from https://www.apachelounge.com/download/ in a browser and copy the zip to the VM, e.g. `C:\Users\Administrator\Downloads\httpd.zip`).

Once confirmed, extract it:

```powershell
Expand-Archive -Path "$env:TEMP\httpd.zip" -DestinationPath "C:\" -Force
```

This extracts to `C:\Apache24\`. Install the Windows service:

```powershell
cd "C:\Apache24\bin"
.\httpd.exe -k install
```

> You may see a warning here: `AH00558: httpd.exe: Could not reliably determine the server's fully qualified domain name...`. This is expected — the service still installs successfully — but set `ServerName` explicitly to silence it:

```powershell
(Get-Content "C:\Apache24\conf\httpd.conf") -replace '#ServerName www.example.com:80', 'ServerName localhost:80' | Set-Content "C:\Apache24\conf\httpd.conf"
```

Start the service:

```powershell
Start-Service Apache2.4
```

### Validate

```powershell
Get-Service Apache2.4
Invoke-WebRequest -Uri "http://localhost/" -UseBasicParsing
```

**Expected:** `Status` = `Running` and an HTTP `200` response with the default Apache test page.

---

### Exercise 2 — Enable `mod_status` on Apache

### Task
Expose Apache's internal status page so the collector can scrape it.

### Steps

Edit `httpd.conf` (typically `C:\Apache24\conf\httpd.conf`):

```powershell
notepad "C:\Apache24\conf\httpd.conf"
```

Confirm this line is **uncommented** (loads mod_status):

```apacheconf
LoadModule status_module modules/mod_status.so
```

Add the status location block:

```apacheconf
<Location "/server-status">
    SetHandler server-status
    Require local
</Location>
ExtendedStatus On
```

Restart Apache:

```powershell
Restart-Service Apache2.4
```

### Validate mod_status directly

```powershell
Invoke-WebRequest -Uri "http://localhost/server-status?auto" -UseBasicParsing
```

**Expected:** plain-text output with fields like `Total Accesses`, `Total kBytes`, `BusyWorkers`, `IdleWorkers`.

---

### Exercise 3 — Add the Apache Receiver to the Collector

### Task
Configure the OTel Collector to scrape the Apache status endpoint.

### Steps

```powershell
notepad "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
```

Add under `receivers:`:

```yaml
receivers:
  apache:
    endpoint: "http://localhost:80/server-status?auto"
    collection_interval: 10s
```

Merge `apache` into the existing `metrics:` pipeline's `receivers:` list:

```yaml
service:
  pipelines:
    metrics:
      receivers: [host_metrics, otlp, apache]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [signalfx]
```

Validate and restart:

```powershell
& "C:\Program Files\Splunk\OpenTelemetry Collector\otelcol.exe" validate --config "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
Restart-Service splunk-otel-collector
```

**If restart fails**, check the real error:

```powershell
Get-EventLog -LogName Application -Source "splunk-otel-collector" -Newest 20
```

### Validate in the UI
1. **Metrics finder** → search `apache.requests`, `apache.workers`, `apache.traffic`.
2. **Infrastructure → Hosts → [host]** → confirm the Apache navigator/section appears.

---


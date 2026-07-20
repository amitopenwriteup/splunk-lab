# Lab: ASP.NET App on IIS — Windows Server

**Objective:** Configure metrics and APM trace collection for an ASP.NET application hosted on IIS, and validate in Splunk Observability Cloud.

**Assumes:** The Splunk OTel Collector for Windows is already installed and running as the `splunk-otel-collector` Windows service.

**Estimated time:** 25–35 minutes

**Config file:** `C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml`

> Note: This lab is written for a general ASP.NET / IIS setup. Verify exact package names, receiver options, and installer URLs against current Splunk Observability Cloud documentation before running in a real environment — some commands below are illustrative and may need adjustment for your OS/collector version.

---

## Prerequisites

Run PowerShell **as Administrator**.

```powershell
Get-Service splunk-otel-collector
Copy-Item "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml" `
          "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml.bak"
```

---

## Exercise 1 — Install IIS and the .NET Hosting Bundle

```powershell
Install-WindowsFeature -Name Web-Server -IncludeManagementTools

# Install the .NET Hosting Bundle (enables IIS to host ASP.NET Core apps)
# CORRECTED: the old "/download/pr/latest/" pseudo-link is deprecated and
# now returns HTTP 400. Use winget instead of a hardcoded URL, since it
# always resolves to a valid current package.
winget install Microsoft.DotNet.HostingBundle.9
# ^ swap ".9" for whichever major .NET version your app targets (e.g. .8)
#
# Alternative if winget isn't available: get a real, versioned URL from
# https://dotnet.microsoft.com/en-us/download/dotnet (select your version →
# "Hosting Bundle"), then:
#   $url = "<versioned-url-from-the-download-page>"
#   $out = "$env:TEMP\dotnet-hosting-win.exe"
#   Invoke-WebRequest -Uri $url -OutFile $out
#   Start-Process -FilePath $out -ArgumentList "/quiet /norestart" -Wait

# Deploy a sample app (or your own) to the default site
Import-Module WebAdministration
New-Item -Path "C:\inetpub\wwwroot\dotnetlab" -ItemType Directory -Force
# ... copy your published app files into C:\inetpub\wwwroot\dotnetlab ...

New-WebApplication -Site "Default Web Site" -Name "dotnetlab" `
    -PhysicalPath "C:\inetpub\wwwroot\dotnetlab" -ApplicationPool "DefaultAppPool"

Restart-Service W3SVC
```

### Validate

```powershell
Get-Service W3SVC
Invoke-WebRequest -Uri "http://localhost/dotnetlab/" -UseBasicParsing | Select-Object StatusCode
```

**Expected:** `Status: Running` and HTTP `200`.

---

## Exercise 2 — Enable Performance Counters for IIS / ASP.NET

Windows exposes IIS metrics via Performance Counters, which the collector reads directly (no extra agent config needed on the app side).

> **CORRECTED:** The original version of this exercise checked the `ASP.NET Apps v4.0.30319` counter set. That counter set only exists for **classic ASP.NET apps running .NET Framework** — it is *not* registered by ASP.NET Core apps, which is what Exercise 1 actually deployed (via the .NET Hosting Bundle / ASP.NET Core Module on IIS). Checking it here would return an error or an empty set, not "0 with no traffic."
>
> ASP.NET Core apps don't expose the classic per-app ASP.NET counters at all — under IIS they only get the generic `Process` counters for the worker process (`w3wp`), plus whatever the app emits itself (which is what Exercise 3/4's OTel receiver and auto-instrumentation are for). So this exercise now checks IIS-level counters only, which apply regardless of ASP.NET Framework vs. ASP.NET Core.

```powershell
# Confirm the relevant counter set is present
Get-Counter -ListSet "Web Service" | Select-Object CounterSetName

# Optional: confirm the IIS worker process is exposing generic Process counters
Get-Counter -ListSet "Process" | Select-Object CounterSetName
```

### Validate

```powershell
Get-Counter -Counter "\Web Service(_Total)\Current Connections"
Get-Counter -Counter "\Process(w3wp)\% Processor Time"
```

**Expected:** Counter values return without error (0 is fine if there's no traffic yet).

---

## Exercise 3 — Add the Windows Performance Counters Receiver to the Collector

```powershell
notepad "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
```

Add under `receivers:`:

```yaml
# CORRECTED: removed the "ASP.NET Apps v4.0.30319" perfcounter block —
# it doesn't apply to the ASP.NET Core app deployed in Exercise 1 (see the
# note in Exercise 2). Left only the IIS-level "Web Service" counters,
# which are valid for any app hosted under IIS.
receivers:
  windowsperfcounters/iis:
    collection_interval: 10s
    metrics:
      iis.request.count:
        description: "Number of requests handled by IIS"
        unit: "{requests}"
        gauge:
    perfcounters:
      - object: "Web Service"
        instances: ["_Total"]
        counters:
          - name: "Current Connections"
          - name: "Total Bytes Received"
          - name: "Total Bytes Sent"
```

Add `windowsperfcounters/iis` to the `metrics:` pipeline:

```yaml
service:
  pipelines:
    metrics:
      receivers: [hostmetrics, otlp, windowsperfcounters/iis]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [signalfx]
```

```powershell
Restart-Service splunk-otel-collector
Get-EventLog -LogName Application -Source "splunk-otel-collector" -Newest 50
```

### Validate in the UI
**Metrics finder** → search `iis.request.count`, `Web Service Current Connections`.

---

## Exercise 4 — Instrument the .NET App for APM Traces

```powershell
# Download and run the Splunk OTel .NET auto-instrumentation installer
$module_url = "https://github.com/signalfx/splunk-otel-dotnet/releases/latest/download/splunk-otel-dotnet-install.ps1"
$download_path = Join-Path $env:TEMP "install.ps1"
Invoke-WebRequest -Uri $module_url -OutFile $download_path
& $download_path

# Load the helper module and register instrumentation for IIS
Import-Module "$env:ProgramFiles\Splunk\OpenTelemetry .NET\Splunk.OTel.DotNet.psm1"
Register-OpenTelemetryForIIS

# Set service name / endpoint via IIS app pool environment variables
$appPoolName = "DefaultAppPool"
[System.Environment]::SetEnvironmentVariable("OTEL_SERVICE_NAME", "dotnet-lab", "Machine")
[System.Environment]::SetEnvironmentVariable("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4318", "Machine")
[System.Environment]::SetEnvironmentVariable("OTEL_RESOURCE_ATTRIBUTES", "deployment.environment=lab", "Machine")

iisreset
Invoke-WebRequest -Uri "http://localhost/dotnetlab/" -UseBasicParsing | Out-Null
```

### Validate in the UI
**APM → Traces** → filter by service name `dotnet-lab`.

---

## Final Validation

```powershell
Get-EventLog -LogName Application -Source "splunk-otel-collector" -Newest 100
Get-Service W3SVC
```

- **Infrastructure → Hosts → [host]** → Windows / IIS navigator appears.
- **Metrics finder** → `iis.*` and `Web Service` counters resolve.
- **APM → Traces** → `dotnet-lab` service shows recent traces.

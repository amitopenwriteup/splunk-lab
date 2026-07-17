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
$url = "https://download.visualstudio.microsoft.com/download/pr/latest/dotnet-hosting-win.exe"
$out = "$env:TEMP\dotnet-hosting-win.exe"
Invoke-WebRequest -Uri $url -OutFile $out
Start-Process -FilePath $out -ArgumentList "/quiet /norestart" -Wait

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

Windows exposes IIS and ASP.NET metrics via Performance Counters, which the collector reads directly (no extra agent config needed on the app side).

```powershell
# Confirm the relevant counter sets are present
Get-Counter -ListSet "Web Service" | Select-Object CounterSetName
Get-Counter -ListSet "ASP.NET Apps v4.0.30319" | Select-Object CounterSetName
```

### Validate

```powershell
Get-Counter -Counter "\Web Service(_Total)\Current Connections"
Get-Counter -Counter "\ASP.NET Apps v4.0.30319(_Total)\Requests/Sec"
```

**Expected:** Counter values return without error (0 is fine if there's no traffic yet).

---

## Exercise 3 — Add the Windows Performance Counters Receiver to the Collector

```powershell
notepad "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
```

Add under `receivers:`:

```yaml
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
      - object: "ASP.NET Apps v4.0.30319"
        instances: ["_Total"]
        counters:
          - name: "Requests/Sec"
          - name: "Errors Total/Sec"
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
**Metrics finder** → search `iis.request.count`, `Web Service Current Connections`, `ASP.NET Apps Requests/Sec`.

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

# Lab: ASP.NET App on IIS — Windows

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
if ((Get-CimInstance Win32_OperatingSystem).ProductType -eq 1) {
    # Client OS (Windows 10/11)
    Enable-WindowsOptionalFeature -Online -FeatureName `
        IIS-WebServerRole, IIS-WebServer, IIS-CommonHttpFeatures, `
        IIS-ManagementConsole, IIS-ManagementScriptingTools, IIS-HttpErrors, `
        IIS-ApplicationDevelopment, IIS-NetFxExtensibility45, `
        IIS-ISAPIExtensions, IIS-ISAPIFilter, IIS-ASPNET45 -All
} else {
    # Windows Server
    Install-WindowsFeature -Name Web-Server -IncludeManagementTools
}

# Install the .NET Hosting Bundle (enables IIS to host ASP.NET Core apps)
winget install Microsoft.DotNet.HostingBundle.9
# ^ swap ".9" for whichever major .NET version your app targets (e.g. .8)

# Deploy a sample app (or your own) to the default site
Import-Module WebAdministration
New-Item -Path "C:\inetpub\wwwroot\dotnetlab" -ItemType Directory -Force

# Quick sanity check — confirms IIS + routing work before deploying a real app.
# Skip this if you're deploying an actual ASP.NET Core app below.
"<h1>It works</h1>" | Out-File "C:\inetpub\wwwroot\dotnetlab\index.html"

# To deploy a real ASP.NET Core app instead, publish it directly into the folder:
#   dotnet publish -c Release -o C:\inetpub\wwwroot\dotnetlab
# (Without this step the folder is empty and IIS returns 403.14 - Forbidden,
# since directory browsing is off and there's no default document.)

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

## Exercise 2 — Enable Performance Counters for IIS

Windows exposes IIS metrics via Performance Counters, which the collector reads directly (no extra agent config needed on the app side).

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

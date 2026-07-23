# Lab: ASP.NET App on IIS — Windows

**Objective:** Configure metrics and APM trace collection for an ASP.NET application hosted on IIS, and validate in Splunk Observability Cloud.

**Assumes:** The Splunk OTel Collector for Windows is already installed and running as the `splunk-otel-collector` Windows service.

**Estimated time:** 30–40 minutes

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


Restart-Service W3SVC
```

### Validate

```powershell
Get-Service W3SVC
Invoke-WebRequest -Uri "http://localhost/" -UseBasicParsing | Select-Object StatusCode
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
Get-Counter -Counter "\Process(w3wp*)\% Processor Time"
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
        description: "Total number of requests received by IIS"
        unit: "{requests}"
        gauge:
      iis.current_connections:
        description: "Current number of connections to the Web Service"
        unit: "{connections}"
        gauge:
      iis.bytes_received:
        description: "Total bytes received by the Web Service"
        unit: "By"
        gauge:
      iis.bytes_sent:
        description: "Total bytes sent by the Web Service"
        unit: "By"
        gauge:
    perfcounters:
      - object: "Web Service"
        instances: ["_Total"]
        counters:
          - name: "Total Method Requests"
            metric: iis.request.count
          - name: "Current Connections"
            metric: iis.current_connections
          - name: "Total Bytes Received"
            metric: iis.bytes_received
          - name: "Total Bytes Sent"
            metric: iis.bytes_sent
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
**Metrics finder** → search `iis.request.count`, `iis.current_connections`, `iis.bytes_received`, `iis.bytes_sent`.

---

## Exercise 4 — Enable AlwaysOn Profiling (CPU and Memory) for the .NET App

The guided **Configure Integration** wizard in Splunk APM (Service name / Service version / Environment / AlwaysOn profiling) writes out the same environment variables you can set by hand for an IIS-hosted app pool. This exercise wires up CPU and memory profiling so profiles show up alongside traces in APM.

> Confirm the exact variable names and the required .NET auto-instrumentation package version against current Splunk Observability Cloud .NET documentation — profiler env var names have changed across releases.

### 4.1 Set service metadata and profiler environment variables on the app pool

```powershell
Import-Module WebAdministration

$appPoolName = "DefaultAppPool"   # swap for your app's app pool

# Core service identity (mirrors "Service name / Service version / Environment")
[System.Environment]::SetEnvironmentVariable("OTEL_SERVICE_NAME", "dotnetlab", "Machine")
[System.Environment]::SetEnvironmentVariable("OTEL_RESOURCE_ATTRIBUTES", "deployment.environment=lab,service.version=1.0.0", "Machine")

# AlwaysOn Profiling — CPU and memory
[System.Environment]::SetEnvironmentVariable("SPLUNK_PROFILER_ENABLED", "true", "Machine")
[System.Environment]::SetEnvironmentVariable("SPLUNK_PROFILER_MEMORY_ENABLED", "true", "Machine")

# Apply the same variables at the IIS app-pool level so w3wp.exe inherits them
New-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name "processModel.environmentVariables" `
  -Value @{ "OTEL_SERVICE_NAME"="dotnetlab";
            "OTEL_RESOURCE_ATTRIBUTES"="deployment.environment=lab,service.version=1.0.0";
            "SPLUNK_PROFILER_ENABLED"="true";
            "SPLUNK_PROFILER_MEMORY_ENABLED"="true" } -ErrorAction SilentlyContinue
```

If your collector/instrumentation version doesn't support `processModel.environmentVariables` directly, set the same variables via `appcmd`:

```powershell
appcmd.exe set config -section:system.applicationHost/applicationPools `
  "/[name='$appPoolName'].environmentVariables.[name='SPLUNK_PROFILER_ENABLED',value='true']" /commit:apphost

appcmd.exe set config -section:system.applicationHost/applicationPools `
  "/[name='$appPoolName'].environmentVariables.[name='SPLUNK_PROFILER_MEMORY_ENABLED',value='true']" /commit:apphost
```

### 4.2 Recycle the app pool and restart IIS

```powershell
Restart-WebAppPool -Name $appPoolName
Restart-Service W3SVC
```

### 4.3 Generate some load

```powershell
1..20 | ForEach-Object { Invoke-WebRequest -Uri "http://localhost/" -UseBasicParsing | Out-Null }
```

### Validate

```powershell
# Confirm the app pool picked up the variables
Get-ItemProperty -Path "IIS:\AppPools\$appPoolName" -Name "processModel.environmentVariables"
```

**In Splunk Observability Cloud:**
- **APM → Service Map** → confirm `dotnetlab` appears with environment `lab`.
- Open a trace for the service → **AlwaysOn Profiling** panel → confirm both **CPU** and **Memory** call stacks are present for the sampled trace span.

**Expected:** The service shows up with profiling data attached to spans, with separate CPU and memory profile views available.

---

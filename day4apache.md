# Lab: Apache, Tomcat, WebSphere (WAS) & Jenkins Instrumentation — Windows

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

> ⚠️ Throughout this lab, you will be **adding receivers to existing pipelines**, not creating new `metrics:`/`traces:` keys. YAML does not allow duplicate top-level keys — merge into the existing pipeline blocks instead.

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

## Part B — Apache Tomcat

### Exercise 4 — Enable JMX Remote on Tomcat

### Task
Expose Tomcat's JVM metrics via JMX so the collector's JMX receiver can scrape them.

### Steps

If running Tomcat as a Windows service, open the **Tomcat Properties** utility:

```powershell
& "C:\Tomcat9\bin\tomcat9w.exe" //ES//Tomcat9
```

Go to the **Java** tab and add to **Java Options**:

```
-Dcom.sun.management.jmxremote
-Dcom.sun.management.jmxremote.port=9012
-Dcom.sun.management.jmxremote.rmi.port=9012
-Dcom.sun.management.jmxremote.local.only=false
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false
-Djava.rmi.server.hostname=localhost
```

> For production, enable JMX authentication/SSL instead of disabling them — this lab uses open JMX for simplicity.

Alternatively, if Tomcat runs from a batch script, edit `setenv.bat` (create if missing, in `C:\Tomcat9\bin\`):

```powershell
notepad "C:\Tomcat9\bin\setenv.bat"
```

```batch
set CATALINA_OPTS=%CATALINA_OPTS% -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9012 -Dcom.sun.management.jmxremote.rmi.port=9012 -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=localhost
```

Restart Tomcat:

```powershell
Restart-Service Tomcat9
```

### Validate JMX is listening

```powershell
Get-NetTCPConnection -LocalPort 9012 -ErrorAction SilentlyContinue
```

**Expected:** an entry showing the port in `Listen` state.

---

### Exercise 5 — Add the JMX Receiver for Tomcat Metrics

### Task
Configure the collector to pull JVM/Tomcat metrics via JMX.

### Steps

Download the OpenTelemetry JMX metrics gatherer JAR:

```powershell
New-Item -ItemType Directory -Force -Path "C:\Program Files\Splunk\OpenTelemetry Collector\jmx"
Invoke-WebRequest -Uri "https://github.com/open-telemetry/opentelemetry-java-contrib/releases/latest/download/opentelemetry-jmx-metrics.jar" -OutFile "C:\Program Files\Splunk\OpenTelemetry Collector\jmx\opentelemetry-jmx-metrics.jar"
```

Edit the config:

```powershell
notepad "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
```

Add under `receivers:`:

```yaml
receivers:
  jmx/tomcat:
    jar_path: C:\Program Files\Splunk\OpenTelemetry Collector\jmx\opentelemetry-jmx-metrics.jar
    endpoint: localhost:9012
    target_system: tomcat
    collection_interval: 10s
```

Merge into the `metrics:` pipeline:

```yaml
service:
  pipelines:
    metrics:
      receivers: [host_metrics, otlp, apache, jmx/tomcat]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [signalfx]
```

Validate and restart:

```powershell
& "C:\Program Files\Splunk\OpenTelemetry Collector\otelcol.exe" validate --config "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
Restart-Service splunk-otel-collector
```

### Validate in the UI
- **Metrics finder** → search `tomcat.sessions`, `tomcat.threads`, `tomcat.errors`, `jvm.memory.heap.used`.

---

### Exercise 6 — Enable APM Traces for Tomcat (Java Auto-Instrumentation)

### Task
Attach the Splunk OTel Java agent so incoming HTTP requests to Tomcat show up as traces in APM.

### Steps

Download the Java agent:

```powershell
Invoke-WebRequest -Uri "https://github.com/signalfx/splunk-otel-java/releases/latest/download/splunk-otel-javaagent.jar" -OutFile "C:\Tomcat9\splunk-otel-javaagent.jar"
```

Open the **Tomcat Properties** utility again (or edit `setenv.bat`) and add to Java Options:

```
-javaagent:C:\Tomcat9\splunk-otel-javaagent.jar
-Dotel.service.name=tomcat-app
-Dotel.exporter.otlp.endpoint=http://localhost:4317
-Dotel.resource.attributes=deployment.environment=lab
```

Or via `setenv.bat`:

```batch
set JAVA_OPTS=%JAVA_OPTS% -javaagent:C:\Tomcat9\splunk-otel-javaagent.jar -Dotel.service.name=tomcat-app -Dotel.exporter.otlp.endpoint=http://localhost:4317 -Dotel.resource.attributes=deployment.environment=lab
```

Restart Tomcat:

```powershell
Restart-Service Tomcat9
```

### Generate traffic and validate

```powershell
Invoke-WebRequest -Uri "http://localhost:8080/" -UseBasicParsing
```

Go to **APM → Service Map** in Splunk Observability Cloud and confirm `tomcat-app` appears within 1–2 minutes.

---

## Part C — IBM WebSphere Application Server (WAS)

### Exercise 7 — Enable PMI and JMX Connector on WAS

### Task
Turn on WebSphere's Performance Monitoring Infrastructure (PMI) and expose it via JMX.

### Steps

1. Log in to the **WebSphere Admin Console** (typically `https://localhost:9043/ibm/console`).
2. Go to **Monitoring and Tuning → Performance Monitoring Infrastructure (PMI)**.
3. Select your server, click **Configuration**, check **Enable Performance Monitoring Infrastructure (PMI)**, and set the monitoring level (e.g. **Extended** or **All**).
4. Go to **Servers → Server Types → WebSphere application servers → [server] → Ports** and note the **RMI/SOAP connector port** (e.g. `SOAP_CONNECTOR_ADDRESS` or `ORB_LISTENER_ADDRESS`).
5. **Save** and restart the WebSphere server for changes to take effect.

### Validate

```powershell
Get-NetTCPConnection -LocalPort <was-jmx-port> -ErrorAction SilentlyContinue
```

Confirm the port shows in `Listen` state.

---

### Exercise 8 — Add the JMX Receiver for WAS Metrics

### Task
Configure the collector to pull PMI/JVM metrics from WebSphere via JMX.

> WebSphere is not one of the OTel JMX receiver's built-in `target_system` presets (unlike Tomcat, Kafka, Cassandra). Use a **custom Groovy metrics script** instead, or start with generic `jvm` metrics and extend later.

### Steps — Minimal (JVM-level metrics only)

```powershell
notepad "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
```

```yaml
receivers:
  jmx/was:
    jar_path: C:\Program Files\Splunk\OpenTelemetry Collector\jmx\opentelemetry-jmx-metrics.jar
    endpoint: localhost:<was-jmx-port>
    target_system: jvm
    collection_interval: 15s
```

### Steps — Extended (custom PMI MBeans via Groovy script)

Create a custom script that queries WebSphere PMI MBeans directly:

```powershell
notepad "C:\Program Files\Splunk\OpenTelemetry Collector\jmx\was-custom.groovy"
```

```groovy
// Example: capture WebSphere thread pool size from PMI MBeans
def threadPoolBeans = otel.mbeans("WebSphere:type=ThreadPool,*")
threadPoolBeans.each { bean ->
    def poolSize = otel.long(bean, "PoolSize")
    otel.instrument(poolSize, "was.threadpool.size", "WebSphere thread pool size", "1")
}
```

Reference the script in the receiver instead of `target_system`:

```yaml
receivers:
  jmx/was:
    jar_path: C:\Program Files\Splunk\OpenTelemetry Collector\jmx\opentelemetry-jmx-metrics.jar
    endpoint: localhost:<was-jmx-port>
    groovy_script: C:\Program Files\Splunk\OpenTelemetry Collector\jmx\was-custom.groovy
    collection_interval: 15s
```

Merge into the `metrics:` pipeline (use whichever receiver name you configured — minimal or extended):

```yaml
service:
  pipelines:
    metrics:
      receivers: [host_metrics, otlp, apache, jmx/tomcat, jmx/was]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [signalfx]
```

Validate and restart:

```powershell
& "C:\Program Files\Splunk\OpenTelemetry Collector\otelcol.exe" validate --config "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
Restart-Service splunk-otel-collector
```

### Validate in the UI
- **Metrics finder** → search `jvm.memory.heap.used` (minimal) or `was.threadpool.size` (extended, if using the custom script).

---

### Exercise 9 — Enable APM Traces for WAS (Java Auto-Instrumentation)

### Task
Attach the Splunk OTel Java agent to WebSphere so incoming requests show up as traces.

### Steps

Download the agent (same JAR as Tomcat):

```powershell
Invoke-WebRequest -Uri "https://github.com/signalfx/splunk-otel-java/releases/latest/download/splunk-otel-javaagent.jar" -OutFile "C:\IBM\WebSphere\AppServer\splunk-otel-javaagent.jar"
```

In the **WebSphere Admin Console**:
1. Go to **Servers → Server Types → WebSphere application servers → [server] → Java and Process Management → Process Definition → Java Virtual Machine**.
2. In **Generic JVM arguments**, add:
   ```
   -javaagent:C:\IBM\WebSphere\AppServer\splunk-otel-javaagent.jar
   -Dotel.service.name=was-app
   -Dotel.exporter.otlp.endpoint=http://localhost:4317
   -Dotel.resource.attributes=deployment.environment=lab
   ```
3. **Save**, then restart the WebSphere server.

### Generate traffic and validate

```powershell
Invoke-WebRequest -Uri "http://localhost:9080/" -UseBasicParsing
```

Go to **APM → Service Map** in Splunk Observability Cloud and confirm `was-app` appears within 1–2 minutes.

---

## Part D — Jenkins

### Exercise 10 — Install Jenkins

### Task
Install Jenkins as a Windows service using the official MSI installer.

### Steps

Reference: [Jenkins Windows installation docs](https://www.jenkins.io/doc/book/installing/windows/)

Download the current stable (LTS) Windows MSI installer:

```powershell
Invoke-WebRequest -Uri "https://get.jenkins.io/windows-stable/latest/jenkins.msi" -OutFile "$env:TEMP\jenkins.msi" -UseBasicParsing

Test-Path "$env:TEMP\jenkins.msi"
```

Confirm `Test-Path` returns `True` before continuing — don't proceed to install if the download silently failed.

Run a silent install (default install path `C:\Program Files\Jenkins`, default port `8080`, runs as `LOCALSYSTEM`):

```powershell
Start-Process msiexec.exe -ArgumentList '/i', "$env:TEMP\jenkins.msi", '/qn', '/norestart' -Wait
```

> For production, install with a dedicated service account instead of `LOCALSYSTEM` — see the [Windows installation docs](https://www.jenkins.io/doc/book/installing/windows/) for the `SERVICE_USERNAME`/`SERVICE_PASSWORD` MSI properties and the required **Log on as a service** local security policy grant.

### Validate

```powershell
Get-Service Jenkins
Invoke-WebRequest -Uri "http://localhost:8080/" -UseBasicParsing
```

**Expected:** `Status` = `Running`, and the response shows the **Unlock Jenkins** page (HTTP 200/403 with a login/unlock prompt is normal at this stage — full setup wizard completion isn't required for this lab).

---

### Exercise 11 — Enable JMX Remote on Jenkins

### Task
Expose Jenkins' JVM metrics via JMX so the collector's JMX receiver can scrape them.

### Steps

Jenkins runs as a Windows service via `jenkins.exe`/`winsw`. Edit its service configuration to add JVM arguments.

```powershell
notepad "C:\Program Files\Jenkins\jenkins.xml"
```

Inside the `<arguments>` element (or `<launcher>`/`<startargument>` entries depending on version), add:

```
-Dcom.sun.management.jmxremote
-Dcom.sun.management.jmxremote.port=9013
-Dcom.sun.management.jmxremote.rmi.port=9013
-Dcom.sun.management.jmxremote.local.only=false
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.ssl=false
-Djava.rmi.server.hostname=localhost
```

> For production, enable JMX authentication/SSL instead of disabling them — this lab uses open JMX for simplicity.
>
> Alternatively, set the `JENKINS_JAVA_OPTIONS` environment variable (System Properties → Environment Variables) with the same flags, then restart the service — this avoids hand-editing the service XML on some Jenkins packaging versions.

Restart the service:

```powershell
Restart-Service Jenkins
```

### Validate JMX is listening

```powershell
Get-NetTCPConnection -LocalPort 9013 -ErrorAction SilentlyContinue
```

**Expected:** an entry showing the port in `Listen` state.

---

### Exercise 12 — Add the JMX Receiver for Jenkins Metrics

### Task
Configure the collector to pull JVM/Jenkins metrics via JMX.

> Jenkins is not one of the OTel JMX receiver's built-in `target_system` presets (unlike Tomcat). Use generic `jvm` metrics as a baseline, and optionally extend with a custom Groovy script for Jenkins-specific MBeans (domain `jenkins` / `hudson.*`).

### Steps — Minimal (JVM-level metrics only)

```powershell
notepad "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
```

```yaml
receivers:
  jmx/jenkins:
    jar_path: C:\Program Files\Splunk\OpenTelemetry Collector\jmx\opentelemetry-jmx-metrics.jar
    endpoint: localhost:9013
    target_system: jvm
    collection_interval: 15s
```

### Steps — Extended (custom Jenkins MBeans via Groovy script)

```powershell
notepad "C:\Program Files\Splunk\OpenTelemetry Collector\jmx\jenkins-custom.groovy"
```

```groovy
// Example: capture Jenkins queue size and executor count from its JMX MBeans
def queueBeans = otel.mbeans("jenkins:type=Queue,*")
queueBeans.each { bean ->
    def queueSize = otel.long(bean, "Size")
    otel.instrument(queueSize, "jenkins.queue.size", "Jenkins build queue size", "1")
}
```

Reference the script in the receiver instead of `target_system`:

```yaml
receivers:
  jmx/jenkins:
    jar_path: C:\Program Files\Splunk\OpenTelemetry Collector\jmx\opentelemetry-jmx-metrics.jar
    endpoint: localhost:9013
    groovy_script: C:\Program Files\Splunk\OpenTelemetry Collector\jmx\jenkins-custom.groovy
    collection_interval: 15s
```

Merge into the `metrics:` pipeline (use whichever receiver name you configured — minimal or extended):

```yaml
service:
  pipelines:
    metrics:
      receivers: [host_metrics, otlp, apache, jmx/tomcat, jmx/was, jmx/jenkins]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [signalfx]
```

Validate and restart:

```powershell
& "C:\Program Files\Splunk\OpenTelemetry Collector\otelcol.exe" validate --config "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
Restart-Service splunk-otel-collector
```

### Validate in the UI
- **Metrics finder** → search `jvm.memory.heap.used` (minimal) or `jenkins.queue.size` (extended, if using the custom script).

---

### Exercise 13 — Enable APM Traces for Jenkins (Java Auto-Instrumentation)

### Task
Attach the Splunk OTel Java agent to Jenkins so incoming HTTP requests to the Jenkins UI/API show up as traces.

### Steps

Download the agent (same JAR used for Tomcat/WAS):

```powershell
Invoke-WebRequest -Uri "https://github.com/signalfx/splunk-otel-java/releases/latest/download/splunk-otel-javaagent.jar" -OutFile "C:\Program Files\Jenkins\splunk-otel-javaagent.jar"
```

Add to `JENKINS_JAVA_OPTIONS` (System Properties → Environment Variables), or directly into `jenkins.xml`'s arguments:

```
-javaagent:C:\Program Files\Jenkins\splunk-otel-javaagent.jar
-Dotel.service.name=jenkins-app
-Dotel.exporter.otlp.endpoint=http://localhost:4317
-Dotel.resource.attributes=deployment.environment=lab
```

Restart the service:

```powershell
Restart-Service Jenkins
```

### Generate traffic and validate

```powershell
Invoke-WebRequest -Uri "http://localhost:8080/" -UseBasicParsing
```

Go to **APM → Service Map** in Splunk Observability Cloud and confirm `jenkins-app` appears within 1–2 minutes.

---

## Final Validation Checklist

| Component | Metrics check | Trace check |
|---|---|---|
| Apache | `apache.requests` in Metrics finder | n/a (metrics only) |
| Tomcat | `tomcat.sessions`, `jvm.memory.heap.used` | `tomcat-app` in APM Service Map |
| WebSphere (WAS) | `jvm.memory.heap.used` or `was.threadpool.size` | `was-app` in APM Service Map |
| Jenkins | `jvm.memory.heap.used` or `jenkins.queue.size` | `jenkins-app` in APM Service Map |

---

## Troubleshooting

| Issue | Check |
|---|---|
| Apache metrics missing | Confirm `Invoke-WebRequest http://localhost/server-status?auto` returns data locally first |
| JMX receiver fails to start | Confirm the JAR path is correct and the target JMX port is listening (`Get-NetTCPConnection`) |
| Collector restart fails | YAML syntax error — check for duplicate pipeline keys; run `otelcol.exe validate` before restarting |
| No traces in APM | Confirm the app was actually restarted after adding `-javaagent`; check `-Dotel.exporter.otlp.endpoint` points to `localhost:4317` |
| WAS custom Groovy script errors | Check collector logs (`Get-EventLog -LogName Application -Source "splunk-otel-collector"`) for Groovy syntax/MBean-not-found errors — confirm MBean names via `jconsole` first |
| Jenkins service won't start after editing `jenkins.xml` | Validate the XML is well-formed; check `C:\Program Files\Jenkins\jenkins.err.log` and `jenkins.wrapper.log` for startup errors |
| Config file not found under Program Files | Config/logs live under `C:\ProgramData\...`, not `C:\Program Files\...` — only binaries are there |

---

## Cleanup (Optional)

```powershell
Copy-Item "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml.bak" "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml" -Force
Restart-Service splunk-otel-collector
```

Remove the `-javaagent` flags from Tomcat's Java Options / WAS Generic JVM arguments / Jenkins `JENKINS_JAVA_OPTIONS` and restart the respective services.

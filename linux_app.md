# Lab: Apache, Tomcat & WebSphere (WAS) Instrumentation — Linux

**Objective:** Configure metrics and APM trace collection for Apache HTTP Server, Apache Tomcat, and IBM WebSphere Application Server (WAS) on Linux, and validate all three in Splunk Observability Cloud.

**Assumes:** The Splunk OTel Collector is already installed and running (`splunk-otel-collector` service active). This lab only covers application-level instrumentation.

**Estimated time:** 40–50 minutes

**Config file:** `/etc/otel/collector/agent_config.yaml`

---

## Lab Prerequisites

```bash
sudo systemctl status splunk-otel-collector
```

Confirm `active (running)` before continuing.

Back up the config before making any changes:

```bash
sudo cp /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.yaml.bak
```

> ⚠️ Throughout this lab, you will be **adding receivers to existing pipelines**, not creating new `metrics:`/`traces:` keys. YAML does not allow duplicate top-level keys — merge into the existing pipeline blocks instead.

---

## Part A — Apache HTTP Server

### Exercise 1 — Install Apache HTTP Server

### Task
Install Apache if it isn't already present on the host.

### Steps

```bash
# Debian/Ubuntu
sudo apt-get update
sudo apt-get install -y apache2
```

```bash
# RHEL/CentOS
sudo yum install -y httpd
```

Enable and start the service:

```bash
sudo systemctl enable apache2 && sudo systemctl start apache2   # Debian/Ubuntu
# or
sudo systemctl enable httpd && sudo systemctl start httpd       # RHEL/CentOS
```

### Validate

```bash
sudo systemctl status apache2   # Debian/Ubuntu
# or
sudo systemctl status httpd     # RHEL/CentOS

curl -I http://localhost/
```

**Expected:** `active (running)` and an `HTTP/1.1 200 OK` response.

---

### Exercise 2 — Enable `mod_status` on Apache

### Task
Expose Apache's internal status page so the collector can scrape it.

### Steps

```bash
sudo a2enmod status   # Debian/Ubuntu — enables mod_status
```

Edit the status config (Debian/Ubuntu: `/etc/apache2/mods-enabled/status.conf`; RHEL: add to `httpd.conf`):

```apacheconf
<Location "/server-status">
    SetHandler server-status
    Require local
</Location>
ExtendedStatus On
```

Restart Apache:

```bash
sudo systemctl restart apache2   # Debian/Ubuntu
# or
sudo systemctl restart httpd     # RHEL/CentOS
```

### Validate mod_status directly

```bash
curl "http://localhost/server-status?auto"
```

**Expected:** plain-text output with fields like `Total Accesses`, `Total kBytes`, `BusyWorkers`, `IdleWorkers`.

---

### Exercise 3 — Add the Apache Receiver to the Collector

### Task
Configure the OTel Collector to scrape the Apache status endpoint.

### Steps

```bash
sudo nano /etc/otel/collector/agent_config.yaml
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

```bash
sudo cp /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.yaml.bak2
sudo systemctl restart splunk-otel-collector
sudo systemctl status splunk-otel-collector
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

Edit Tomcat's startup environment file (create if it doesn't exist):

```bash
sudo nano /opt/tomcat/bin/setenv.sh
```

Add:

```bash
CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote"
CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.port=9012"
CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.rmi.port=9012"
CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.local.only=false"
CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.authenticate=false"
CATALINA_OPTS="$CATALINA_OPTS -Dcom.sun.management.jmxremote.ssl=false"
CATALINA_OPTS="$CATALINA_OPTS -Djava.rmi.server.hostname=localhost"
```

> For production, enable JMX authentication/SSL instead of disabling them — this lab uses open JMX for simplicity.

Restart Tomcat:

```bash
sudo systemctl restart tomcat
```

### Validate JMX is listening

```bash
sudo ss -tlnp | grep 9012
```

**Expected:** a process listening on port `9012`.

---

### Exercise 5 — Add the JMX Receiver for Tomcat Metrics

### Task
Configure the collector to pull JVM/Tomcat metrics via JMX.

### Steps

The JMX receiver needs the OpenTelemetry JMX metrics gatherer JAR. Download it if not already present:

```bash
sudo mkdir -p /usr/lib/splunk-otel-collector/jmx
sudo curl -L -o /usr/lib/splunk-otel-collector/jmx/opentelemetry-jmx-metrics.jar \
  https://github.com/open-telemetry/opentelemetry-java-contrib/releases/latest/download/opentelemetry-jmx-metrics.jar
```

Edit the config:

```bash
sudo nano /etc/otel/collector/agent_config.yaml
```

Add under `receivers:`:

```yaml
receivers:
  jmx/tomcat:
    jar_path: /usr/lib/splunk-otel-collector/jmx/opentelemetry-jmx-metrics.jar
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

```bash
sudo systemctl restart splunk-otel-collector
sudo journalctl -u splunk-otel-collector -f --since "2 minutes ago"
```

### Validate in the UI
- **Metrics finder** → search `tomcat.sessions`, `tomcat.threads`, `tomcat.errors`, `jvm.memory.heap.used`.

---

### Exercise 6 — Enable APM Traces for Tomcat (Java Auto-Instrumentation)

### Task
Attach the Splunk OTel Java agent so incoming HTTP requests to Tomcat show up as traces in APM.

### Steps

Download the Java agent:

```bash
sudo curl -L -o /opt/tomcat/splunk-otel-javaagent.jar \
  https://github.com/signalfx/splunk-otel-java/releases/latest/download/splunk-otel-javaagent.jar
```

Add to `setenv.sh`:

```bash
sudo nano /opt/tomcat/bin/setenv.sh
```

```bash
export JAVA_OPTS="$JAVA_OPTS -javaagent:/opt/tomcat/splunk-otel-javaagent.jar"
export OTEL_SERVICE_NAME="tomcat-app"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://localhost:4317"
export OTEL_RESOURCE_ATTRIBUTES="deployment.environment=lab"
```

Restart Tomcat:

```bash
sudo systemctl restart tomcat
```

### Generate traffic and validate

```bash
curl http://localhost:8080/
```

Go to **APM → Service Map** in Splunk Observability Cloud and confirm `tomcat-app` appears within 1–2 minutes.

---

## Part C — IBM WebSphere Application Server (WAS)

### Exercise 7 — Enable PMI and JMX Connector on WAS

### Task
Turn on WebSphere's Performance Monitoring Infrastructure (PMI) and expose it via JMX.

### Steps

1. Log in to the **WebSphere Admin Console**.
2. Go to **Monitoring and Tuning → Performance Monitoring Infrastructure (PMI)**.
3. Select your server, click **Configuration**, check **Enable Performance Monitoring Infrastructure (PMI)**, and set the monitoring level (e.g. **Extended** or **All**).
4. Go to **Servers → Server Types → WebSphere application servers → [server] → Administration → Custom Properties** (or **Java and Process Management → Process Definition → Java Virtual Machine → Custom Properties**) and confirm JMX connector is on the **SOAP** or **RMI** connector type — RMI is preferred for the JMX receiver.
5. Note the **RMI/SOAP connector port** (**Ports** tab on the server config page — e.g. `SOAP_CONNECTOR_ADDRESS` or `ORB_LISTENER_ADDRESS`).
6. **Save** and restart the WebSphere server for changes to take effect.

### Validate

```bash
sudo ss -tlnp | grep <was-jmx-port>
```

Confirm the port is listening.

---

### Exercise 8 — Add the JMX Receiver for WAS Metrics

### Task
Configure the collector to pull PMI/JVM metrics from WebSphere via JMX.

> WebSphere is not one of the OTel JMX receiver's built-in `target_system` presets (unlike Tomcat, Kafka, Cassandra). Use a **custom Groovy metrics script** instead, or start with generic `jvm` metrics and extend later.

### Steps — Minimal (JVM-level metrics only)

```bash
sudo nano /etc/otel/collector/agent_config.yaml
```

```yaml
receivers:
  jmx/was:
    jar_path: /usr/lib/splunk-otel-collector/jmx/opentelemetry-jmx-metrics.jar
    endpoint: localhost:<was-jmx-port>
    target_system: jvm
    collection_interval: 15s
```

### Steps — Extended (custom PMI MBeans via Groovy script)

Create a custom script that queries WebSphere PMI MBeans directly:

```bash
sudo nano /usr/lib/splunk-otel-collector/jmx/was-custom.groovy
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
    jar_path: /usr/lib/splunk-otel-collector/jmx/opentelemetry-jmx-metrics.jar
    endpoint: localhost:<was-jmx-port>
    groovy_script: /usr/lib/splunk-otel-collector/jmx/was-custom.groovy
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

```bash
sudo systemctl restart splunk-otel-collector
sudo journalctl -u splunk-otel-collector -f --since "2 minutes ago"
```

### Validate in the UI
- **Metrics finder** → search `jvm.memory.heap.used` (minimal) or `was.threadpool.size` (extended, if using the custom script).

---

### Exercise 9 — Enable APM Traces for WAS (Java Auto-Instrumentation)

### Task
Attach the Splunk OTel Java agent to WebSphere so incoming requests show up as traces.

### Steps

Download the agent (same JAR as Tomcat):

```bash
sudo curl -L -o /opt/IBM/WebSphere/AppServer/splunk-otel-javaagent.jar \
  https://github.com/signalfx/splunk-otel-java/releases/latest/download/splunk-otel-javaagent.jar
```

In the **WebSphere Admin Console**:
1. Go to **Servers → Server Types → WebSphere application servers → [server] → Java and Process Management → Process Definition → Java Virtual Machine**.
2. In **Generic JVM arguments**, add:
   ```
   -javaagent:/opt/IBM/WebSphere/AppServer/splunk-otel-javaagent.jar
   -Dotel.service.name=was-app
   -Dotel.exporter.otlp.endpoint=http://localhost:4317
   -Dotel.resource.attributes=deployment.environment=lab
   ```
3. **Save**, then restart the WebSphere server.

### Generate traffic and validate

```bash
curl http://localhost:9080/
```

Go to **APM → Service Map** in Splunk Observability Cloud and confirm `was-app` appears within 1–2 minutes.

---

## Final Validation Checklist

| Component | Metrics check | Trace check |
|---|---|---|
| Apache | `apache.requests` in Metrics finder | n/a (metrics only) |
| Tomcat | `tomcat.sessions`, `jvm.memory.heap.used` | `tomcat-app` in APM Service Map |
| WebSphere (WAS) | `jvm.memory.heap.used` or `was.threadpool.size` | `was-app` in APM Service Map |

---

## Troubleshooting

| Issue | Check |
|---|---|
| Apache metrics missing | Confirm `curl http://localhost/server-status?auto` returns data locally first |
| JMX receiver fails to start | Confirm the JAR path is correct and the target JMX port is listening (`ss -tlnp`) |
| Collector restart fails | YAML syntax error — check for duplicate pipeline keys, confirm with `.bak` restore |
| No traces in APM | Confirm the app was actually restarted after adding `-javaagent`; check `OTEL_EXPORTER_OTLP_ENDPOINT`/`-Dotel.exporter.otlp.endpoint` points to `localhost:4317` |
| WAS custom Groovy script errors | Check collector logs (`journalctl -u splunk-otel-collector`) for Groovy syntax/MBean-not-found errors — confirm MBean names via `jconsole` first |

---

## Cleanup (Optional)

```bash
sudo cp /etc/otel/collector/agent_config.yaml.bak /etc/otel/collector/agent_config.yaml
sudo systemctl restart splunk-otel-collector
```

Remove the `-javaagent` flags from `setenv.sh` / WAS Generic JVM arguments and restart the respective app servers.

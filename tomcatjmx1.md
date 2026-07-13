# Lab: Apache Tomcat — Rocky Linux

**Objective:** Configure metrics and APM trace collection for Apache Tomcat on Rocky Linux, and validate in Splunk Observability Cloud.

**Assumes:** The Splunk OTel Collector is already installed and running as the `splunk-otel-collector` systemd service.

**Estimated time:** 25–35 minutes

**Config file:** `/etc/otel/collector/agent_config.yaml`

---

## Prerequisites

```bash
sudo systemctl status splunk-otel-collector
sudo cp /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.yaml.bak
```

---

## Exercise 1 — Install Apache Tomcat

```bash
sudo dnf install -y java-17-openjdk tomcat tomcat-webapps tomcat-admin-webapps
sudo systemctl enable --now tomcat
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

### Validate

```bash
sudo systemctl status tomcat
curl -I http://localhost:8080/
```

**Expected:** `Active: active (running)` and HTTP `200`.

---

## Exercise 2 — Enable JMX Remote on Tomcat

Comment out the existing `JAVA_OPTS` line and replace it with a new one:

```bash
sudo sed -i '/^JAVA_OPTS=/ s/^/#/' /etc/tomcat/tomcat.conf

sudo tee -a /etc/tomcat/tomcat.conf > /dev/null <<'EOF'
JAVA_OPTS="-Djavax.sql.DataSource.Factory=org.apache.commons.dbcp.BasicDataSourceFactory -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9012 -Dcom.sun.management.jmxremote.rmi.port=9012 -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=localhost"
EOF

sudo systemctl restart tomcat
```

### Validate

```bash
ss -ltnp | grep 9012
```

**Expected:** a listener on port `9012`.

---

## Exercise 3 — Add the Tomcat (JMX) Receiver to the Collector

```bash
find / -iname "*jmx-metric*" 2>/dev/null
which otelcol
```

```bash
sudo vi /etc/otel/collector/agent_config.yaml
```

Add under `receivers:`:

```yaml
receivers:
  jmx/tomcat:
    jar_path: /opt/opentelemetry-java-contrib-jmx-metrics.jar
    endpoint: localhost:9012
    target_system: tomcat
    collection_interval: 10s
```

Add `jmx/tomcat` to the `metrics:` pipeline:

```yaml
service:
  pipelines:
    metrics:
      receivers: [hostmetrics, otlp, jmx/tomcat]
      processors: [memory_limiter, batch, resourcedetection]
      exporters: [signalfx]
```

```bash
sudo systemctl restart splunk-otel-collector
sudo journalctl -u splunk-otel-collector -n 50 --no-pager
```

### Validate in the UI
**Metrics finder** → search `tomcat.sessions`, `tomcat.threads`, `jvm.memory.heap.used`.

---

## Exercise 4 — Instrument Tomcat for APM Traces

```bash
sudo mkdir -p /opt/splunk-otel-javaagent
sudo curl -L -o /opt/splunk-otel-javaagent/splunk-otel-javaagent.jar \
  https://github.com/signalfx/splunk-otel-java/releases/latest/download/splunk-otel-javaagent.jar
ls -lh /opt/splunk-otel-javaagent/splunk-otel-javaagent.jar
```

Comment out the `JAVA_OPTS` line from Exercise 2 and replace it with a new one that adds the javaagent:

```bash
sudo sed -i '/^JAVA_OPTS=/ s/^/#/' /etc/tomcat/tomcat.conf

sudo tee -a /etc/tomcat/tomcat.conf > /dev/null <<'EOF'
JAVA_OPTS="-Djavax.sql.DataSource.Factory=org.apache.commons.dbcp.BasicDataSourceFactory -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9012 -Dcom.sun.management.jmxremote.rmi.port=9012 -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=localhost -javaagent:/opt/splunk-otel-javaagent/splunk-otel-javaagent.jar"
OTEL_SERVICE_NAME=tomcat-lab
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=lab
EOF

sudo systemctl restart tomcat
curl http://localhost:8080/ > /dev/null
```

### Validate in the UI
**APM → Traces** → filter by service name `tomcat-lab`.

---

## Final Validation

```bash
sudo journalctl -u splunk-otel-collector -n 100 --no-pager
sudo systemctl status tomcat
```

- **Infrastructure → Hosts → [host]** → Tomcat (JMX) navigator appears.
- **Metrics finder** → `tomcat.*` and `jvm.memory.heap.used` resolve.
- **APM → Traces** → `tomcat-lab` service shows recent traces.

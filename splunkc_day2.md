# Splunk Observability Cloud — Data Collection Setup Guide

Covers three ways to get telemetry into Splunk Observability Cloud: the OpenTelemetry (OTel) Collector, the HTTP Event Collector (HEC), and automated installation with Terraform.

---

## 1. OpenTelemetry (OTel) Collector — Installation & Configuration

The **Splunk Distribution of the OpenTelemetry Collector** receives, processes, and exports metrics, traces, and logs to Splunk Observability Cloud. It's supported on Linux, Windows, and Kubernetes.

### Prerequisites

- Your **Splunk Observability Cloud realm** (e.g., `us0`, `us1`, `eu0`)
  Find it: **Settings → View Profile → Organizations**
- A **Splunk Observability Cloud access token**
  Find/create it: **Settings → Access Tokens**

### Install on Linux

1. Set environment variables in your terminal:
   ```bash
   export SPLUNK_REALM="<your_realm>"
   export SPLUNK_ACCESS_TOKEN="<your_access_token>"
   export SPLUNK_MEMORY_TOTAL_MIB="512"
   ```

2. Download and run the installer script:
   ```bash
   curl -sSL https://dl.observability.splunkcloud.com/splunk-otel-collector.sh > /tmp/splunk-otel-collector.sh
   sudo sh /tmp/splunk-otel-collector.sh \
     --realm "$SPLUNK_REALM" \
     --memory "$SPLUNK_MEMORY_TOTAL_MIB" \
     -- "$SPLUNK_ACCESS_TOKEN"
   ```

3. Verify the service is running:
   ```bash
   sudo systemctl status splunk-otel-collector
   ```

4. Locate the configuration files:
   ```bash
   ls /etc/otel/collector
   # agent_config.yaml   gateway_config.yaml   splunk-otel-collector.conf   config.d
   ```

### Install with Docker (testing/containerized use)

```bash
docker run -d \
  --name splunk-otel-collector \
  -e SPLUNK_ACCESS_TOKEN=YOUR_TOKEN \
  -e SPLUNK_REALM=us1 \
  -e SPLUNK_CONFIG=/etc/otel/collector/gateway_config.yaml \
  -p 4317:4317 \
  -p 4318:4318 \
  -p 13133:13133 \
  -p 9943:9943 \
  quay.io/signalfx/splunk-otel-collector:latest
```

### Deployment Modes

| Mode | Description |
|------|-------------|
| **Agent** | Collector runs on the same host as the application. Recommended default. |
| **Gateway** | One or more standalone Collector instances (per cluster/datacenter/region), useful when agent hosts can't reach Splunk Observability Cloud directly. |

### Configuration Structure

Every Collector config file (YAML) is built from these components:

- **Receivers** — how data gets in (e.g., `otlp`, `hostmetrics`, `filelog`)
- **Processors** — transform data before export (e.g., `batch`, `memory_limiter`, `resourcedetection`)
- **Exporters** — where data goes (e.g., `signalfx`, `otlphttp`, `splunk_hec`)
- **Connectors** — join two pipelines
- **Extensions** — add capabilities like health checks (`health_check`, `zpages`)
- **Service → Pipelines** — ties receivers, processors, and exporters together per data type (`traces`, `metrics`, `logs`)

Example minimal pipeline:

```yaml
receivers:
  otlp:
    protocols:
      grpc:
      http:
  hostmetrics:
    collection_interval: 10s
    scrapers:
      cpu:
      memory:
      disk:

processors:
  batch:
  memory_limiter:
    check_interval: 1s
    limit_mib: 512

exporters:
  signalfx:
    access_token: "${SPLUNK_ACCESS_TOKEN}"
    realm: "${SPLUNK_REALM}"
  otlphttp:
    endpoint: "https://ingest.${SPLUNK_REALM}.signalfx.com"

service:
  pipelines:
    metrics:
      receivers: [otlp, hostmetrics]
      processors: [memory_limiter, batch]
      exporters: [signalfx]
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [otlphttp]
```

> Receivers and exporters only take effect once referenced inside a `service.pipelines` block.

---

## 2. HEC (HTTP Event Collector) — Installation & Configuration

HEC is Splunk's token-based HTTP/HTTPS API for sending data into a Splunk platform deployment (Splunk Enterprise or Splunk Cloud Platform). Within the OTel Collector, HEC works in two directions:

- **`splunk_hec` exporter** — sends Collector data *out* to a Splunk HEC endpoint
- **`splunk_hec` receiver** — lets the Collector *receive* data already in HEC format

### Step 1: Enable HEC on the Splunk Platform side

1. In Splunk Web: **Settings → Add Data → Monitor → HTTP Event Collector**
2. Create a new token, give it a name, and (optionally) assign a source, sourcetype, and index
3. Confirm the token is **enabled**
4. Note the HEC endpoint URL, typically:
   `https://<splunk_host>:8088/services/collector`
   (Splunk Cloud Platform: `https://http-inputs-<host>.splunkcloud.com:443/services/collector`)

> On Splunk Cloud Platform, HEC is enabled by default — you only need to create a token.

### Step 2: Configure the `splunk_hec` exporter in the Collector

```yaml
exporters:
  splunk_hec/logs:
    token: "${SPLUNK_HEC_TOKEN}"
    endpoint: "https://splunk:8088/services/collector"
    source: "otel"
    sourcetype: "otel"
    tls:
      insecure_skip_verify: true   # only for self-signed certs / testing

service:
  pipelines:
    logs:
      receivers: [filelog, otlp]
      processors: [batch]
      exporters: [splunk_hec/logs]
```

Useful exporter options:

| Option | Purpose |
|--------|---------|
| `profiling_data_enabled: false` | Disable AlwaysOn Profiling data if not needed |
| `log_data_enabled: false` | Turn off log export (e.g., if using Log Observer Connect instead) |
| `index` | Route data to a specific Splunk index |

### Step 3 (optional): Configure the `splunk_hec` receiver

Use this if another system is already sending data in HEC format and you want the Collector to ingest it directly.

```yaml
receivers:
  splunk_hec:
    endpoint: 0.0.0.0:8088

service:
  pipelines:
    logs:
      receivers: [splunk_hec]
      processors: [batch]
      exporters: [signalfx]
```

### Step 4: Restart the Collector

```bash
sudo systemctl restart splunk-otel-collector
```

---

## 3. Installation with Terraform Automation

Terraform can deploy the Collector (via the Kubernetes Helm chart) and manage Splunk Observability Cloud resources (dashboards, detectors, tokens) as code.

### Option A: Deploy the Collector to Kubernetes with Terraform + Helm provider

```hcl
terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "helm_release" "splunk_otel_collector" {
  name       = "splunk-otel-collector"
  repository = "https://signalfx.github.io/splunk-otel-collector-chart"
  chart      = "splunk-otel-collector"
  namespace  = "otel"
  create_namespace = true

  set {
    name  = "splunkObservability.realm"
    value = var.splunk_realm
  }

  set_sensitive {
    name  = "splunkObservability.accessToken"
    value = var.splunk_access_token
  }

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
}

variable "splunk_realm" {
  type = string
}

variable "splunk_access_token" {
  type      = string
  sensitive = true
}

variable "cluster_name" {
  type = string
}
```

Apply it:

```bash
terraform init
terraform plan -var="splunk_realm=us0" -var="splunk_access_token=xxxxx" -var="cluster_name=my-cluster"
terraform apply -var="splunk_realm=us0" -var="splunk_access_token=xxxxx" -var="cluster_name=my-cluster"
```

### Option B: Manage Splunk Observability Cloud resources with the Splunk Terraform provider

Use this to manage dashboards, detectors, and integrations as code (separate from Collector deployment).

```hcl
terraform {
  required_providers {
    signalfx = {
      source  = "splunk-terraform/signalfx"
      version = "~> 9.0"
    }
  }
}

provider "signalfx" {
  auth_token = var.splunk_access_token
  api_url    = "https://api.${var.splunk_realm}.signalfx.com"
}
```

From here you can define resources such as `signalfx_dashboard`, `signalfx_detector`, and `signalfx_aws_integration` to codify what would otherwise be manual UI configuration.

### Why Terraform for this?

- Version-controlled, auditable Collector and dashboard configuration
- Repeatable deployments across clusters/environments
- Centralized change management instead of manual `helm install`/UI clicks
- Easier rollback if a config change causes data issues

---

## Quick Reference

| Task | Where |
|------|-------|
| Get realm/access token | Settings → Access Tokens / View Profile |
| OTel Collector config files (Linux) | `/etc/otel/collector/` |
| HEC token creation | Splunk Web → Settings → Add Data → HTTP Event Collector |
| Collector Helm chart | `https://signalfx.github.io/splunk-otel-collector-chart` |
| Terraform provider for Observability Cloud | `splunk-terraform/signalfx` |

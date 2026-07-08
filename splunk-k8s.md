# Setting Up a Local Kubernetes (kind) Cluster with Splunk Observability Cloud

This guide walks through creating a local **kind** (Kubernetes in Docker) cluster and connecting it to **Splunk Observability Cloud** using the Splunk Distribution of the OpenTelemetry Collector.

---

## Prerequisites

- Docker installed and running
- `kubectl` installed
- `helm` (v3) installed
- A Splunk Observability Cloud account with admin access
- An org access token with **ingest** scope

---

## Step 1: Create the kind cluster

```bash
# Install kind if you don't have it
brew install kind          # macOS
# or
go install sigs.k8s.io/kind@latest

# Create the cluster
kind create cluster --name my-cluster

# Confirm it's up
kubectl cluster-info --context kind-my-cluster
```

---

## Step 2: Get your Observability Cloud access token and realm

1. In Splunk Observability Cloud, go to **Settings → Access Tokens** (or **Organization Settings → API Access Tokens**).
2. Create a new token, or copy an existing one, with **ingest authorization scope**.
3. Note your **realm** (e.g. `us0`, `us1`, `eu0`) — visible in your Observability Cloud URL, for example:
   `https://app.us1.signalfx.com` → realm is `us1`.

---

## Step 3: Add the Splunk OpenTelemetry Collector Helm repo

```bash
helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart
helm repo update
```

---

## Step 4: Install the Collector via Helm

### Option A — quick install with `--set` flags

```bash
helm install splunk-otel-collector \
  --set="splunkObservability.accessToken=<ACCESS_TOKEN>" \
  --set="clusterName=my-cluster" \
  --set="splunkObservability.realm=<REALM>" \
  --set="gateway.enabled=false" \
  --set="splunkObservability.profilingEnabled=true" \
  --set="environment=dev" \
  splunk-otel-collector-chart/splunk-otel-collector
```

### Option B — recommended for version control: `values.yaml`

```yaml
# values.yaml
clusterName: my-cluster
environment: dev

splunkObservability:
  accessToken: "<ACCESS_TOKEN>"
  realm: "<REALM>"
  profilingEnabled: true

gateway:
  enabled: false
```

```bash
helm install splunk-otel-collector \
  --values values.yaml \
  splunk-otel-collector-chart/splunk-otel-collector
```

This deploys:
- An **agent DaemonSet** on each node — collects metrics, logs, and traces.
- A **cluster receiver** (single pod) — collects cluster-wide Kubernetes metrics and events.

---

## Step 5: Verify the deployment

```bash
kubectl get pods -l app=splunk-otel-collector
kubectl logs -l app=splunk-otel-collector --tail=50
```

All pods should show `Running` status. Check the logs for any connection or authentication errors.

---

## Step 6: View data in Splunk Observability Cloud

1. Go to **Infrastructure → Kubernetes → K8s nodes** or **K8s pods**.
2. Filter by cluster name: `my-cluster`.
3. Data typically appears within a couple of minutes of a successful install.

---

## Notes for kind-specific setups

- kind runs Kubernetes nodes as Docker containers using **containerd** internally — no special collector configuration is needed for log or metric collection; it behaves like any standard Kubernetes distribution.
- If your kind cluster or Docker host is behind a **corporate proxy**, configure proxy settings under `agent.config` in `values.yaml`, or the collector pods won't be able to reach the Splunk ingest endpoint.
- kind clusters are **not for production** — this setup is intended for local development, testing, or training purposes.

---

## Optional next steps

- **Forward logs to Splunk Cloud Platform** in addition to Observability Cloud (requires an HEC token and endpoint — see `splunkPlatform.endpoint` and `splunkPlatform.token` values).
- **Enable AlwaysOn Profiling** for APM (already set via `profilingEnabled: true` above).
- **Set up alerting** on Kubernetes node/pod health once data starts flowing.

---

## Uninstalling

```bash
helm uninstall splunk-otel-collector
kind delete cluster --name my-cluster
```

# Workshop: Splunk Enterprise 10.4.0 + Kubernetes (KinD) Monitoring

> **Level:** Intermediate
> **Duration:** ~3–4 hours
> **Environment:** Local machine running KinD (Kubernetes in Docker)
> **Goal:** Set up Splunk Enterprise 10.4.0 on a Linux host, deploy the Splunk OpenTelemetry Collector into a local KinD cluster, and build dashboards to monitor your Kubernetes environment.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Architecture Overview](#2-architecture-overview)
3. [Install Splunk Enterprise 10.4.0](#3-install-splunk-enterprise-1040)
4. [Configure Splunk Enterprise — Indexes and HEC Token](#4-configure-splunk-enterprise--indexes-and-hec-token)
5. [Remove Podman and Install Docker CE](#5-remove-podman-and-install-docker-ce)
6. [Install and Verify KinD](#6-install-and-verify-kind)
7. [Create a KinD Cluster](#7-create-a-kind-cluster)
8. [Install kubectl and Verify Cluster Access](#8-install-kubectl-and-verify-cluster-access)
9. [Install Helm](#9-install-helm)
10. [Deploy Splunk OpenTelemetry Collector for Kubernetes](#10-deploy-splunk-opentelemetry-collector-for-kubernetes)
11. [Deploy a Sample Application](#11-deploy-a-sample-application)
12. [Verify Data Flow into Splunk Enterprise](#12-verify-data-flow-into-splunk-enterprise)
13. [Build Kubernetes Monitoring Dashboards](#13-build-kubernetes-monitoring-dashboards)
14. [Set Up Alerts](#14-set-up-alerts)
15. [Troubleshooting](#15-troubleshooting)
16. [Clean Up](#16-clean-up)

---

## 1. Prerequisites

Before starting, make sure the following are installed and available on your local machine.

### Required Software

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Docker CE | 20.x or later | Required by KinD to run cluster nodes as containers |
| KinD | v0.20+ | Kubernetes in Docker — local cluster |
| kubectl | v1.27+ | CLI to interact with your cluster |
| Helm | v3.12+ | Package manager for Kubernetes |
| A web browser | Any modern browser | Splunk Enterprise Web UI |

> **Important:** This workshop uses **Docker CE**, not Podman. KinD's Podman provider is experimental and causes IPv6 subnet pool errors on RHEL 9. See [Step 5](#5-remove-podman-and-install-docker-ce) to remove Podman and install Docker CE before proceeding.

### Hardware Recommendations

- **CPU:** 4 cores minimum (6+ recommended)
- **RAM:** 8 GB minimum (16 GB recommended)
- **Disk:** 20 GB free space

### Splunk Enterprise Host Requirements

| Requirement | Details |
|-------------|---------|
| OS | RHEL / CentOS / Fedora (x86_64) |
| RAM | Minimum 4 GB (8 GB+ recommended) |
| Disk | Minimum 20 GB free |
| User | Root or sudo privileges |
| Ports | 8000 (Web UI), 9997 (Forwarder), 8088 (HEC), 8089 (Management) |

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────┐
│               Your Local Machine                │
│                                                 │
│  ┌──────────────────────────────────────────┐   │
│  │         KinD Cluster (Docker)            │   │
│  │                                          │   │
│  │  ┌────────────┐   ┌──────────────────┐  │   │
│  │  │Control Plane│   │   Worker Node(s) │  │   │
│  │  └────────────┘   └──────────────────┘  │   │
│  │                                          │   │
│  │  ┌──────────────────────────────────┐   │   │
│  │  │  Splunk OTel Collector (DaemonSet)│   │   │
│  │  │  - Node metrics                  │   │   │
│  │  │  - Container logs                │   │   │
│  │  │  - Kubernetes events             │   │   │
│  │  └──────────────────────────────────┘   │   │
│  │                                          │   │
│  │  ┌──────────────────────────────────┐   │   │
│  │  │     Sample App (nginx/demo)      │   │   │
│  │  └──────────────────────────────────┘   │   │
│  └──────────────────────────────────────────┘   │
│                        │                        │
│              HTTPS / HEC (:8088)                │
│              via Docker bridge 172.18.0.1       │
│                        │                        │
│  ┌─────────────────────▼───────────────────┐    │
│  │     Splunk Enterprise 10.4.0            │    │
│  │     (Running on Linux host)             │    │
│  │                                         │    │
│  │  - Log Search  (port 8000)              │    │
│  │  - Dashboards                           │    │
│  │  - Alerts                               │    │
│  │  - HEC Endpoint (port 8088 / HTTPS)     │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

**Data flow:**
1. The Splunk OTel Collector runs as a DaemonSet on every node in your KinD cluster.
2. It scrapes container logs, node metrics, and Kubernetes API events.
3. It forwards all data over **HTTPS** to your local Splunk Enterprise instance via the Docker bridge IP (`172.18.0.1`) on port `8088`.
4. You search, visualize, and alert on that data inside Splunk Enterprise at `http://<host-ip>:8000`.

---

## 3. Install Splunk Enterprise 10.4.0

### Step 3.1 — Download the RPM Package

```bash
wget -O splunk-10.4.0-f798d4d49089.x86_64.rpm \
  "https://download.splunk.com/products/splunk/releases/10.4.0/linux/splunk-10.4.0-f798d4d49089.x86_64.rpm"
```

**Verify the download:**

```bash
ls -lh splunk-10.4.0-f798d4d49089.x86_64.rpm
rpm --checksig splunk-10.4.0-f798d4d49089.x86_64.rpm
```

---

### Step 3.2 — Install Splunk

```bash
sudo rpm -ivh splunk-10.4.0-f798d4d49089.x86_64.rpm
```

> Splunk is installed to `/opt/splunk` by default.

---

### Step 3.3 — Fix Post-Install Issues (If Encountered)

After RPM installation you may see two warnings. Both are handled below.

#### Warning 1 — `useradd: cannot create directory /opt/splunk`

This appears when the `splunk` system user is created but its home directory cannot be made automatically. The package still installs successfully, but ownership must be corrected before starting.

**Check current ownership:**
```bash
ls -la /opt/splunk
```

**Fix ownership:**
```bash
sudo chown -R splunk:splunk /opt/splunk
```

**If the `splunk` user is missing entirely:**
```bash
sudo useradd -r -m -d /opt/splunk splunk
sudo chown -R splunk:splunk /opt/splunk
```

#### Warning 2 — `find: '/opt/splunk/lib/python3.7/site-packages': No such file or directory`

> ✅ **This is harmless — no action required.**

Splunk 10.4.0 bundles its own Python interpreter internally. The installer probes for a host-level Python 3.7 as a legacy check, but Splunk does **not** depend on it. This warning is expected on RHEL 9 / EL9 systems where `python3.7` is unavailable.

| Warning | Severity | Action |
|---------|----------|--------|
| `useradd: cannot create directory /opt/splunk` | ⚠️ Fix required | `chown -R splunk:splunk /opt/splunk` |
| `find: .../python3.7/site-packages: No such file` | ℹ️ Informational | None — safely ignore |

---

### Step 3.4 — Start Splunk & Accept License

```bash
sudo /opt/splunk/bin/splunk start --accept-license
```

On first start you will be prompted to:
- Set an **admin username** (default: `admin`)
- Set an **admin password** (minimum 8 characters)

---

### Step 3.5 — Enable Splunk to Start on Boot

```bash
sudo /opt/splunk/bin/splunk enable boot-start
```

For **systemd-based** systems (RHEL 7+):

```bash
sudo systemctl enable Splunkd
sudo systemctl start Splunkd
```

---

### Step 3.6 — Open Firewall Ports

```bash
sudo firewall-cmd --permanent --add-port=8000/tcp   # Web UI
sudo firewall-cmd --permanent --add-port=8088/tcp   # HEC (used by collector)
sudo firewall-cmd --permanent --add-port=9997/tcp   # Splunk Forwarder
sudo firewall-cmd --permanent --add-port=8089/tcp   # REST API / Management
sudo firewall-cmd --reload
```

---

### Step 3.7 — Access the Web Interface

Open your browser and navigate to:

```
http://<your-server-ip>:8000
```

Login with the admin credentials you set in Step 3.4.

---

## 4. Configure Splunk Enterprise — Indexes and HEC Token

You need to create dedicated indexes to store Kubernetes data and enable the HTTP Event Collector (HEC) so the OTel Collector can send data in.

### Step 4.1 — Create a Kubernetes Logs Index

1. In Splunk Enterprise, click the **Settings** menu in the top navigation bar.
2. Under the **Data** section, click **Indexes**.
3. Click the **New Index** button (top right).
4. Fill in the form:
   - **Index Name:** `k8s_logs`
   - **Index Data Type:** Events
   - **Max Size of Entire Index:** Leave at default
5. Click **Save**.

Repeat the process to create a second index:

- **Index Name:** `k8s_metrics`
- **Index Data Type:** Metrics

You should now have two new indexes: `k8s_logs` and `k8s_metrics`.

---

### Step 4.2 — Enable the HTTP Event Collector

1. Go to **Settings → Data Inputs**.
2. Find **HTTP Event Collector** in the list and click on it.
3. Click **Global Settings** (top right).
4. Set **All Tokens** to **Enabled**.
5. Confirm the **HTTP Port Number** is set to `8088`.
6. Click **Save**.

---

### Step 4.3 — Create an HEC Token

1. Still on the HTTP Event Collector page, click **New Token**.
2. **Name:** `kubernetes-collector`
3. Click **Next**.
4. On the **Input Settings** page:
   - Under **Allowed Indexes**, add both `k8s_logs` and `k8s_metrics`.
   - Set **Default Index** to `k8s_logs`.
5. Click **Review**, then **Submit**.
6. On the confirmation screen, copy your token value — it looks like:

   ```
   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

7. **Save this token somewhere safe.** You will need it in later steps.

---

### Step 4.4 — Note Your HEC Endpoint

Your local HEC endpoint is:

```
https://<your-server-ip>:8088/services/collector/event
```

> **Important:** Splunk Enterprise enables **SSL on HEC by default** since version 8.x. Port `8088` serves **HTTPS** — not plain HTTP. Always use `https://` with the `-k` flag (skip certificate verification) for local/self-signed certificates. Using `http://` will result in the error `curl: (1) Received HTTP/0.9 when not allowed`.

**Test the HEC endpoint from your machine:**

```bash
curl -k https://<your-server-ip>:8088/services/collector/event \
  -H "Authorization: Splunk <YOUR-HEC-TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"event": "HEC test from workshop", "index": "k8s_logs"}'
```

Expected response: `{"text":"Success","code":0}`

> **If you get `HTTP/0.9 when not allowed`:** You used `http://` instead of `https://`. Add `-k` and switch to `https://` as shown above.

---

## 5. Remove Podman and Install Docker CE

KinD's Podman provider is **experimental** on RHEL 9 and causes the following error when creating clusters:

```
ERROR: failed to create cluster: failed to ensure podman network:
command "podman network create -d=bridge --ipv6 --subnet ... kind" failed
Error: could not find free subnet from subnet pools
```

This happens because Podman exhausts its IPv6 subnet pool. The fix is to remove Podman and use Docker CE instead.

### Step 5.1 — Remove Podman and All Related Packages

```bash
# Stop and disable podman services
systemctl stop podman podman.socket 2>/dev/null
systemctl disable podman podman.socket 2>/dev/null

# Remove podman and all related packages
dnf remove -y podman podman-docker podman-compose \
  containers-common container-selinux \
  buildah skopeo runc crun slirp4netns \
  fuse-overlayfs netavark aardvark-dns

# Clean up config and data directories
rm -rf /etc/containers
rm -rf /var/lib/containers
rm -rf ~/.config/containers
rm -rf ~/.local/share/containers
rm -rf /etc/cni/net.d/*

# Verify podman is removed
which podman || echo "Podman removed successfully"
```

---

### Step 5.2 — Install Docker CE

```bash
# Add Docker CE repository
dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

# Install Docker CE
dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin

# Start and enable Docker
systemctl enable --now docker

# Verify Docker is running
docker version
```

You should see both **Client** and **Server** sections in the output.

---

## 6. Install and Verify KinD

If KinD is already installed, skip to Step 7.

### Step 6.1 — Install KinD on Linux

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Step 6.1 — Install KinD on macOS

```bash
brew install kind
```

### Step 6.1 — Install KinD on Windows

```powershell
winget install Kubernetes.kind
```

### Step 6.2 — Verify KinD Installation

```bash
kind version
```

Expected output:

```
kind v0.23.0 go1.21.x linux/amd64
```

---

## 7. Create a KinD Cluster

### Step 7.1 — Create the Cluster Configuration File

Create a file named `kind-cluster.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: splunk-workshop
networking:
  ipFamily: ipv4          # Force IPv4 only — avoids IPv6 subnet pool issues
  disableDefaultCNI: false
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "ingress-ready=true"
    extraPortMappings:
      - containerPort: 30000
        hostPort: 30000
        protocol: TCP
  - role: worker
    extraMounts:
      - hostPath: /var/log
        containerPath: /var/log
  - role: worker
    extraMounts:
      - hostPath: /var/log
        containerPath: /var/log
```

> The `networking.ipFamily: ipv4` setting forces IPv4-only networking, preventing the IPv6 subnet pool exhaustion error seen with Podman. Creates one control-plane and two worker nodes. `/var/log` is mounted into workers so the collector can read node logs.

### Step 7.2 — Create the Cluster

```bash
kind create cluster --config kind-cluster.yaml
```

This takes **3–5 minutes**. You should now see Docker (not Podman) in the output — no `enabling experimental podman provider` message:

```
Creating cluster "splunk-workshop" ...
 ✓ Ensuring node image (kindest/node:v1.30.0) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-splunk-workshop"
```

### Step 7.3 — Identify the Docker Bridge IP for HEC

KinD nodes run inside Docker containers. The host's `localhost` / `127.0.0.1` is **not** reachable from inside the cluster. You must use the **Docker bridge IP** instead.

```bash
ip addr show | grep -A2 "br-"
```

Look for the bridge interface that has your KinD worker veth interfaces attached (`master br-xxxxxxxx`). Its IP is your HEC target:

```
br-87854c5ffb1c: ...
    inet 172.18.0.1/16 ...    ← use this IP
```

> In most setups this is `172.18.0.1`. The `docker0` bridge (`172.17.0.1`) is typically DOWN — do not use it.

Confirm it is reachable:

```bash
curl -k https://172.18.0.1:8088/services/collector/event \
  -H "Authorization: Splunk <YOUR-HEC-TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"event": "bridge test", "index": "k8s_logs"}'
```

Expected: `{"text":"Success","code":0}`

### Step 7.4 — Verify the Cluster is Up

```bash
kubectl cluster-info --context kind-splunk-workshop
```

---

## 8. Install kubectl and Verify Cluster Access

If `kubectl` is already installed, skip to Step 8.2.

### Step 8.1 — Install kubectl

**Linux:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
```

**macOS:**
```bash
brew install kubectl
```

**Windows:**
```powershell
winget install Kubernetes.kubectl
```

### Step 8.2 — Verify Context and Node Status

```bash
kubectl config current-context
# Expected: kind-splunk-workshop

kubectl get nodes
```

All nodes should show `Ready`:

```
NAME                            STATUS   ROLES           AGE   VERSION
splunk-workshop-control-plane   Ready    control-plane   5m    v1.30.0
splunk-workshop-worker          Ready    <none>          4m    v1.30.0
splunk-workshop-worker2         Ready    <none>          4m    v1.30.0
```

### Step 8.3 — Verify System Pods

```bash
kubectl get pods -n kube-system
```

All pods should show `Running` or `Completed` before proceeding.

---

## 9. Install Helm

### Step 9.1 — Install Helm

**Linux:**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**macOS:**
```bash
brew install helm
```

**Windows:**
```powershell
winget install Helm.Helm
```

### Step 9.2 — Verify Helm Installation

```bash
helm version
```

### Step 9.3 — Add the Splunk Helm Repository

```bash
helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart
helm repo update
```

---

## 10. Deploy Splunk OpenTelemetry Collector for Kubernetes

### Step 10.1 — Create the Monitoring Namespace

```bash
kubectl create namespace splunk-monitoring
```

### Step 10.2 — Create the Helm Values File

The chart already mounts `/var/log` and `/var/lib/docker/containers` internally — do **not** add `extraVolumes` or `extraVolumeMounts` for these paths, as that causes a `Duplicate value` install error.

Use the Docker bridge IP (`172.18.0.1`) identified in Step 7.3 as the HEC endpoint host. Create `values.yaml`:

```bash
cat > values.yaml << 'EOF'
################################################################
# Splunk Enterprise — KinD Workshop
# HEC host: Docker bridge IP 172.18.0.1
# HEC port: 8088 (HTTPS, self-signed cert)
################################################################

splunkPlatform:
  endpoint: "https://172.18.0.1:8088/services/collector/event"
  token: "<YOUR-HEC-TOKEN>"
  index: "k8s_logs"
  metricsIndex: "k8s_metrics"
  insecureSkipVerify: true     # required for self-signed cert

################################################################
# Cluster identification
################################################################
clusterName: "kind-splunk-workshop"
environment: "workshop"

################################################################
# DaemonSet agent — runs on every node
# Note: do NOT add extraVolumes for varlog/varlibdockercontainers
# — the chart defines these internally; duplicates cause install failure
################################################################
agent:
  enabled: true
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi

################################################################
# Cluster receiver — Kubernetes API metrics and events
################################################################
clusterReceiver:
  enabled: true
  resources:
    limits:
      cpu: 200m
      memory: 256Mi
    requests:
      cpu: 50m
      memory: 64Mi

################################################################
# Log collection
################################################################
logsCollection:
  containers:
    enabled: true
    excludeAgentLogs: true
EOF
```

Replace `<YOUR-HEC-TOKEN>` with your actual token from Step 4.3.

---

### Step 10.3 — Install the Splunk OTel Collector Chart

```bash
helm install splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  --namespace splunk-monitoring \
  --values values.yaml
```

Expected output:

```
NAME: splunk-otel-collector
LAST DEPLOYED: <timestamp>
NAMESPACE: splunk-monitoring
STATUS: deployed
REVISION: 1
```

> **If you see `Duplicate value: "varlog"` error:** Remove any `extraVolumes` / `extraVolumeMounts` sections from your `values.yaml` — the chart defines these internally. Run `helm uninstall splunk-otel-collector -n splunk-monitoring` and reinstall with the clean values file above.

---

### Step 10.4 — Verify the Collector Pods are Running

```bash
kubectl get pods -n splunk-monitoring
```

Expected (one agent pod per worker node + one cluster-receiver):

```
NAME                                                    READY   STATUS    RESTARTS   AGE
splunk-otel-collector-agent-abc12                       1/1     Running   0          2m
splunk-otel-collector-agent-def34                       1/1     Running   0          2m
splunk-otel-collector-k8s-cluster-receiver-xyz56        1/1     Running   0          2m
```

### Step 10.5 — Check Collector Logs

```bash
kubectl logs -n splunk-monitoring \
  -l app=splunk-otel-collector,component=otel-collector-agent \
  --tail=50
```

Look for:

```
Everything is ready. Begin running and processing data.
```

---

## 11. Deploy a Sample Application

### Step 11.1 — Create a Namespace

```bash
kubectl create namespace demo-app
```

### Step 11.2 — Deploy nginx

```bash
kubectl create deployment nginx-demo \
  --image=nginx:latest \
  --replicas=3 \
  -n demo-app
```

### Step 11.3 — Expose the Deployment

```bash
kubectl expose deployment nginx-demo \
  --port=80 \
  --type=NodePort \
  -n demo-app
```

### Step 11.4 — Verify the App is Running

```bash
kubectl get pods -n demo-app
```

All 3 pods should show `Running`.

### Step 11.5 — Generate Log Traffic

```bash
kubectl port-forward svc/nginx-demo 8080:80 -n demo-app &

for i in {1..20}; do curl -s http://localhost:8080 > /dev/null; done
```

These requests generate nginx access logs that the collector ships to Splunk Enterprise.

---

## 12. Verify Data Flow into Splunk Enterprise

### Step 12.1 — Open the Splunk Enterprise Search Interface

1. Navigate to `http://<your-server-ip>:8000` in your browser.
2. Log in with your admin credentials.
3. Click **Search & Reporting** in the left navigation bar.

### Step 12.2 — Search for Kubernetes Logs

Set the time range to **Last 15 minutes** and run:

```
index=k8s_logs
| head 20
```

You should see log events with fields such as `host`, `source`, `sourcetype`, `namespace`, `pod`, and `container`.

### Step 12.3 — Search for nginx Access Logs

```
index=k8s_logs namespace=demo-app container=nginx
| table _time, pod, log
```

### Step 12.4 — Search for Kubernetes Events

```
index=k8s_logs sourcetype=kube:events
| head 20
```

### Step 12.5 — Search for Metrics

```
index=k8s_metrics
| head 20
```

> **If no data appears:** Wait 2–3 minutes. Confirm collector pods are `Running` and re-test the HEC endpoint with the `curl` command from Step 7.3.

---

## 13. Build Kubernetes Monitoring Dashboards

> **Panel vs Tab:** A **panel** is a single visualization widget (chart, table, single value). A **tab** is a page divider that groups multiple panels. Each tab contains panels; panels do not contain tabs.

### Step 13.1 — Create a New Classic Dashboard

Classic Dashboards have a clear **Add Panel** button and are recommended for this workshop.

1. In Splunk Enterprise, click **Dashboards** in the left navigation.
2. Click **Create New Dashboard**.
3. Title: `Kubernetes Workshop Overview`
4. Select **Classic Dashboards** (not Dashboard Studio).
5. Click **Create**.

---

### Step 13.2 — How to Add a Panel (Classic Dashboard)

Once inside the dashboard editor:

1. Click **+ Add Panel** at the bottom of any row, or click **Add Panel** in the top toolbar.
2. Select **New** → choose a visualization type (Single Value, Line Chart, Table, Bar Chart).
3. Enter your SPL search in the search box.
4. Set the time range (e.g. Last 60 minutes).
5. Click **Apply** to preview, then give the panel a title.
6. Click **Save** (top right) after adding all panels.

> **If using Dashboard Studio:** The Add Panel button is the **rectangle/square icon (□)** in the top toolbar. Click it to insert a panel onto the canvas. The Dropdown/Multiselect/Text menu that appears is for **input controls** (filters), not panels — press Esc to dismiss it.

---

### Step 13.3 — Add a Pod Count Panel

- Visualization: **Single Value**
- Title: `Total Active Pods`
- Search:
  ```
  index=k8s_logs
  | stats dc(pod) AS "Running Pods"
  ```

---

### Step 13.4 — Add a Log Volume Over Time Panel

- Visualization: **Line Chart**
- Title: `Log Volume by Namespace`
- Search:
  ```
  index=k8s_logs
  | timechart span=1m count AS "Log Events" by namespace
  ```

---

### Step 13.5 — Add a Node CPU Metrics Panel

- Visualization: **Line Chart**
- Title: `Node CPU Utilization`
- Search:
  ```
  index=k8s_metrics metric_name=k8s.node.cpu.utilization
  | timechart span=1m avg(value) AS "CPU Utilization" by k8s.node.name
  ```

---

### Step 13.6 — Add an Error Log Panel

- Visualization: **Table**
- Title: `Recent Error Logs`
- Search:
  ```
  index=k8s_logs (log=*error* OR log=*Error* OR log=*ERROR*)
  | table _time, namespace, pod, container, log
  | sort -_time
  | head 50
  ```

---

### Step 13.7 — Add a Kubernetes Events Panel

- Visualization: **Table**
- Title: `Kubernetes Events`
- Search:
  ```
  index=k8s_logs sourcetype=kube:events
  | eval message=coalesce(message, log)
  | table _time, namespace, reason, message
  | sort -_time
  | head 30
  ```

---

### Step 13.8 — Save the Dashboard

Click **Save** (top right). The dashboard will auto-refresh as new data arrives.

---

## 14. Set Up Alerts

### Step 14.1 — Create a Pod Crash Loop Alert

1. In **Search & Reporting**, run:
   ```
   index=k8s_logs sourcetype=kube:events reason=BackOff
   | stats count AS restart_count by namespace, pod
   | where restart_count > 5
   ```
2. Time range: **Last 15 minutes**.
3. Click **Save As → Alert**.
4. Configure:
   - **Title:** `Pod CrashLoopBackOff Detected`
   - **Alert Type:** Scheduled — Every 5 minutes
   - **Trigger Condition:** Number of Results → Greater than → 0
5. Add a trigger action (email or **Add to Triggered Alerts**).
6. Click **Save**.

### Step 14.2 — Create a High Log Volume Alert

1. Run:
   ```
   index=k8s_logs
   | timechart span=5m count AS log_count by namespace
   | where log_count > 1000
   ```
2. Click **Save As → Alert**.
3. Configure:
   - **Title:** `High Log Volume in Namespace`
   - **Alert Type:** Scheduled — Every 10 minutes
   - **Trigger Condition:** Number of Results → Greater than → 0
4. Click **Save**.

### Step 14.3 — View Triggered Alerts

Go to **Activity → Triggered Alerts** in the Splunk Enterprise navigation to see any fired alerts.

---

## 15. Troubleshooting

### HEC Returns `HTTP/0.9 when not allowed`

**Cause:** Using `http://` against a HTTPS-only port.

```bash
# Wrong
curl http://master:8088/services/collector/event ...

# Correct — use https:// with -k
curl -k https://master:8088/services/collector/event \
  -H "Authorization: Splunk <YOUR-HEC-TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"event": "test", "index": "k8s_logs"}'
```

Update `values.yaml` endpoint to `https://` and run `helm upgrade`.

---

### KinD Cluster Creation Fails — `could not find free subnet from subnet pools`

**Cause:** Podman IPv6 subnet pool exhaustion. Fix: remove Podman and use Docker CE (see [Step 5](#5-remove-podman-and-install-docker-ce)).

If Podman is already removed but the error persists:

```bash
# Clean up stale networks
podman network prune -f 2>/dev/null

# Or force Docker provider explicitly
KIND_EXPERIMENTAL_PROVIDER=docker kind create cluster --config kind-cluster.yaml
```

---

### Helm Install Fails — `Duplicate value: "varlog"`

**Cause:** `extraVolumes` in `values.yaml` duplicates volumes the chart already defines internally.

**Fix:** Remove all `extraVolumes` and `extraVolumeMounts` sections from `values.yaml`, then reinstall:

```bash
helm uninstall splunk-otel-collector -n splunk-monitoring
helm install splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  --namespace splunk-monitoring \
  --values values.yaml
```

---

### Splunk Enterprise Won't Start

```bash
# Check port conflicts
sudo netstat -tlnp | grep 8000

# View internal logs
tail -f /opt/splunk/var/log/splunk/splunkd.log

# Check service status
sudo /opt/splunk/bin/splunk status
```

**Reset admin password:**
```bash
sudo /opt/splunk/bin/splunk edit user admin -password <newpassword> -auth admin:<oldpassword>
```

---

### Collector Pods in CrashLoopBackOff

```bash
kubectl describe pod <pod-name> -n splunk-monitoring
kubectl logs <pod-name> -n splunk-monitoring --previous
```

Common causes:
- **Wrong HEC token** — verify the token matches what was created in Step 4.3
- **Using `http://` instead of `https://`** — update endpoint in `values.yaml`
- **Wrong bridge IP** — confirm `172.18.0.1` is the active KinD bridge (not `172.17.0.1` which is `docker0` and may be DOWN)
- **Firewall blocking port 8088** — ensure `firewall-cmd` rules were applied (Step 3.6)

To apply changes after editing `values.yaml`:

```bash
helm upgrade splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  --namespace splunk-monitoring \
  --values values.yaml
```

---

### No Data in Splunk Search

1. Confirm pods are `Running`.
2. Check collector logs for errors:
   ```bash
   kubectl logs -n splunk-monitoring \
     -l app=splunk-otel-collector,component=otel-collector-agent \
     --tail=100 | grep -i "error\|warn\|fail"
   ```
3. Test HEC from host using the correct bridge IP:
   ```bash
   curl -k https://172.18.0.1:8088/services/collector/event \
     -H "Authorization: Splunk <YOUR-HEC-TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{"event": "test", "index": "k8s_logs"}'
   ```
   Expected: `{"text":"Success","code":0}`
4. Verify `k8s_logs` and `k8s_metrics` indexes exist under **Settings → Indexes**.

---

### Helm Release Stuck

```bash
helm uninstall splunk-otel-collector -n splunk-monitoring
kubectl get pods -n splunk-monitoring -w   # wait for termination

helm install splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  --namespace splunk-monitoring \
  --values values.yaml
```

---

## 16. Clean Up

### Step 16.1 — Uninstall the Helm Release

```bash
helm uninstall splunk-otel-collector -n splunk-monitoring
```

### Step 16.2 — Delete the KinD Cluster

```bash
kind delete cluster --name splunk-workshop
```

Expected output:

```
Deleting cluster "splunk-workshop" ...
Deleted nodes: ["splunk-workshop-control-plane" "splunk-workshop-worker" "splunk-workshop-worker2"]
```

### Step 16.3 — Verify Docker Cleanup

```bash
docker ps | grep splunk-workshop
# Should return no results
```

### Step 16.4 — Remove Local Files (Optional)

```bash
rm kind-cluster.yaml values.yaml
```

### Step 16.5 — Stop Splunk Enterprise (Optional)

```bash
sudo /opt/splunk/bin/splunk stop
# Or via systemd:
sudo systemctl stop Splunkd
```

To fully uninstall Splunk Enterprise:

```bash
sudo /opt/splunk/bin/splunk stop
sudo /opt/splunk/bin/splunk disable boot-start
sudo rpm -e splunk
sudo rm -rf /opt/splunk   # deletes all indexed data
```

---

## Common Splunk Enterprise Management Commands

| Action | Command |
|--------|---------|
| Start Splunk | `sudo /opt/splunk/bin/splunk start` |
| Stop Splunk | `sudo /opt/splunk/bin/splunk stop` |
| Restart Splunk | `sudo /opt/splunk/bin/splunk restart` |
| Check status | `sudo /opt/splunk/bin/splunk status` |
| Check version | `sudo /opt/splunk/bin/splunk version` |
| Change admin password | `sudo /opt/splunk/bin/splunk edit user admin -password <new> -auth admin:<old>` |

---

## Summary

In this workshop you:

1. Installed **Splunk Enterprise 10.4.0** on a Linux host via RPM and resolved post-install warnings
2. Created **dedicated indexes** (`k8s_logs`, `k8s_metrics`) for Kubernetes data
3. Enabled the **HTTP Event Collector (HEC)** on port `8088` (HTTPS) and created an ingestion token
4. Removed **Podman** and installed **Docker CE** to avoid KinD IPv6 subnet pool errors
5. Created a **multi-node KinD cluster** with IPv4-only networking using a config file
6. Identified the **Docker bridge IP** (`172.18.0.1`) as the HEC target reachable from inside KinD
7. Deployed the **Splunk OpenTelemetry Collector** as a DaemonSet using Helm with the correct `values.yaml` (no duplicate volumes)
8. Deployed a **sample nginx application** and generated log traffic
9. Verified **data flow** using Splunk Enterprise search
10. Built a **custom Classic Dashboard** with pod counts, log volume, CPU metrics, and events
11. Configured **alerts** for crash loops and high log volume

---

## Further Reading

- [Splunk OTel Collector for Kubernetes — GitHub](https://github.com/signalfx/splunk-otel-collector-chart)
- [Splunk Enterprise Documentation](https://docs.splunk.com/Documentation/Splunk)
- [Splunk Enterprise 10.4.0 Release Notes](https://docs.splunk.com/Documentation/Splunk/10.4.0/ReleaseNotes)
- [KinD Official Documentation](https://kind.sigs.k8s.io/)
- [Splunk Search Processing Language (SPL) Reference](https://docs.splunk.com/Documentation/Splunk/latest/SearchReference/WhatsInThisManual)
- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)
- [Docker CE Installation Guide](https://docs.docker.com/engine/install/rhel/)

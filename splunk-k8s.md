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
5. [Install and Verify KinD](#5-install-and-verify-kind)
6. [Create a KinD Cluster](#6-create-a-kind-cluster)
7. [Install kubectl and Verify Cluster Access](#7-install-kubectl-and-verify-cluster-access)
8. [Install Helm](#8-install-helm)
9. [Deploy Splunk OpenTelemetry Collector for Kubernetes](#9-deploy-splunk-opentelemetry-collector-for-kubernetes)
10. [Deploy a Sample Application](#10-deploy-a-sample-application)
11. [Verify Data Flow into Splunk Enterprise](#11-verify-data-flow-into-splunk-enterprise)
12. [Build Kubernetes Monitoring Dashboards](#12-build-kubernetes-monitoring-dashboards)
13. [Set Up Alerts](#13-set-up-alerts)
14. [Troubleshooting](#14-troubleshooting)
15. [Clean Up](#15-clean-up)

---

## 1. Prerequisites

Before starting, make sure the following are installed and available on your local machine.

### Required Software

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| Docker Desktop | 20.x or later | Required by KinD to run cluster nodes as containers |
| KinD | v0.20+ | Kubernetes in Docker — local cluster |
| kubectl | v1.27+ | CLI to interact with your cluster |
| Helm | v3.12+ | Package manager for Kubernetes |
| A web browser | Any modern browser | Splunk Enterprise Web UI |

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

### Check Docker is Running

```bash
docker version
```

You should see both Client and Server information. If Docker is not running, start Docker Desktop before proceeding.

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
│                   HTTP / HEC (:8088)             │
│                        │                        │
│  ┌─────────────────────▼───────────────────┐    │
│  │     Splunk Enterprise 10.4.0            │    │
│  │     (Running on Linux host)             │    │
│  │                                         │    │
│  │  - Log Search  (port 8000)              │    │
│  │  - Dashboards                           │    │
│  │  - Alerts                               │    │
│  │  - HEC Endpoint (port 8088)             │    │
│  └─────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

**Data flow:**
1. The Splunk OTel Collector runs as a DaemonSet on every node in your KinD cluster.
2. It scrapes container logs, node metrics, and Kubernetes API events.
3. It forwards all data over HTTP to your **local Splunk Enterprise instance** using the HTTP Event Collector (HEC) on port `8088`.
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
http://<your-server-ip>:8088/services/collector/event
```

> **Note:** Since Splunk Enterprise is running locally (not in the cloud), you use `http://` and port `8088` by default. If you have configured SSL on your Splunk instance, use `https://` and ensure your certificate is valid or set `insecureSkipVerify: true` in the collector values.

**Test the HEC endpoint from your machine:**

```bash
curl http://<your-server-ip>:8088/services/collector/event \
  -H "Authorization: Splunk <YOUR-HEC-TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"event": "HEC test from workshop", "index": "k8s_logs"}'
```

Expected response: `{"text":"Success","code":0}`

---

## 5. Install and Verify KinD

If KinD is already installed, skip to Step 6.

### Step 5.1 — Install KinD on macOS

```bash
brew install kind
```

### Step 5.1 — Install KinD on Linux

```bash
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind
```

### Step 5.1 — Install KinD on Windows

```powershell
winget install Kubernetes.kind
# Or using choco
choco install kind
```

### Step 5.2 — Verify KinD Installation

```bash
kind version
```

Expected output:

```
kind v0.23.0 go1.21.x linux/amd64
```

---

## 6. Create a KinD Cluster

### Step 6.1 — Create the Cluster Configuration File

Create a file named `kind-cluster.yaml`:

```yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: splunk-workshop
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

> Creates a cluster named `splunk-workshop` with one control-plane and two worker nodes. `/var/log` is mounted into workers so the collector can read node logs.

### Step 6.2 — Create the Cluster

```bash
kind create cluster --config kind-cluster.yaml
```

This takes **3–5 minutes**. Expected output:

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

### Step 6.3 — Verify the Cluster is Up

```bash
kubectl cluster-info --context kind-splunk-workshop
```

---

## 7. Install kubectl and Verify Cluster Access

If `kubectl` is already installed, skip to Step 7.2.

### Step 7.1 — Install kubectl

**macOS:**
```bash
brew install kubectl
```

**Linux:**
```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
```

**Windows:**
```powershell
winget install Kubernetes.kubectl
```

### Step 7.2 — Verify Context and Node Status

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

### Step 7.3 — Verify System Pods

```bash
kubectl get pods -n kube-system
```

All pods should show `Running` or `Completed` before proceeding.

---

## 8. Install Helm

### Step 8.1 — Install Helm

**macOS:**
```bash
brew install helm
```

**Linux:**
```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

**Windows:**
```powershell
winget install Helm.Helm
```

### Step 8.2 — Verify Helm Installation

```bash
helm version
```

### Step 8.3 — Add the Splunk Helm Repository

```bash
helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart
helm repo update
```

---

## 9. Deploy Splunk OpenTelemetry Collector for Kubernetes

### Step 9.1 — Create the Monitoring Namespace

```bash
kubectl create namespace splunk-monitoring
```

### Step 9.2 — Create a Secret for the HEC Token

```bash
kubectl create secret generic splunk-hec-secret \
  --from-literal=splunk_hec_token=<YOUR-HEC-TOKEN> \
  -n splunk-monitoring
```

Replace `<YOUR-HEC-TOKEN>` with the token you copied in Step 4.3.

Verify:

```bash
kubectl get secret splunk-hec-secret -n splunk-monitoring
```

### Step 9.3 — Create the Helm Values File

Create a file named `splunk-otel-values.yaml`. Replace `<YOUR-SERVER-IP>` with the IP address of your Splunk Enterprise host:

```yaml
################################################################
# Splunk Platform (Enterprise) connection settings
################################################################
splunkPlatform:
  # HEC endpoint pointing to your local Splunk Enterprise instance
  endpoint: "http://<YOUR-SERVER-IP>:8088/services/collector/event"

  # Token loaded from Kubernetes secret — leave blank here
  token: ""

  # Target indexes created in Step 4.1
  index: "k8s_logs"
  metricsIndex: "k8s_metrics"

  # Set to true if Splunk Enterprise does not have a valid TLS cert
  insecureSkipVerify: true

################################################################
# Cluster identification
################################################################
clusterName: "kind-splunk-workshop"

################################################################
# DaemonSet — runs on every node
################################################################
agent:
  enabled: true

  extraVolumes:
    - name: varlog
      hostPath:
        path: /var/log
    - name: varlibdockercontainers
      hostPath:
        path: /var/lib/docker/containers

  extraVolumeMounts:
    - name: varlog
      mountPath: /var/log
      readOnly: true
    - name: varlibdockercontainers
      mountPath: /var/lib/docker/containers
      readOnly: true

  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi

################################################################
# Cluster receiver — collects Kubernetes API metrics and events
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

################################################################
# Environment tag
################################################################
environment: "workshop"
```

> **Key difference from Splunk Cloud:** The endpoint uses `http://` and your server's local IP on port `8088`, and `insecureSkipVerify: true` is set since a local Splunk Enterprise install typically uses a self-signed certificate.

### Step 9.4 — Install the Splunk OTel Collector Chart

```bash
helm install splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  --namespace splunk-monitoring \
  --values splunk-otel-values.yaml \
  --set splunkPlatform.token=<YOUR-HEC-TOKEN>
```

Expected output:

```
NAME: splunk-otel-collector
LAST DEPLOYED: <timestamp>
NAMESPACE: splunk-monitoring
STATUS: deployed
REVISION: 1
```

### Step 9.5 — Verify the Collector Pods are Running

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

### Step 9.6 — Check Collector Logs

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

## 10. Deploy a Sample Application

### Step 10.1 — Create a Namespace

```bash
kubectl create namespace demo-app
```

### Step 10.2 — Deploy nginx

```bash
kubectl create deployment nginx-demo \
  --image=nginx:latest \
  --replicas=3 \
  -n demo-app
```

### Step 10.3 — Expose the Deployment

```bash
kubectl expose deployment nginx-demo \
  --port=80 \
  --type=NodePort \
  -n demo-app
```

### Step 10.4 — Verify the App is Running

```bash
kubectl get pods -n demo-app
```

All 3 pods should show `Running`.

### Step 10.5 — Generate Log Traffic

```bash
kubectl port-forward svc/nginx-demo 8080:80 -n demo-app &

for i in {1..20}; do curl -s http://localhost:8080 > /dev/null; done
```

These requests generate nginx access logs that the collector ships to Splunk Enterprise.

---

## 11. Verify Data Flow into Splunk Enterprise

### Step 11.1 — Open the Splunk Enterprise Search Interface

1. Navigate to `http://<your-server-ip>:8000` in your browser.
2. Log in with your admin credentials.
3. Click **Search & Reporting** in the left navigation bar.

### Step 11.2 — Search for Kubernetes Logs

Set the time range to **Last 15 minutes** and run:

```
index=k8s_logs
| head 20
```

You should see log events with fields such as `host`, `source`, `sourcetype`, `namespace`, `pod`, and `container`.

### Step 11.3 — Search for nginx Access Logs

```
index=k8s_logs namespace=demo-app container=nginx
| table _time, pod, log
```

### Step 11.4 — Search for Kubernetes Events

```
index=k8s_logs sourcetype=kube:events
| head 20
```

### Step 11.5 — Search for Metrics

```
index=k8s_metrics
| head 20
```

> **If no data appears:** Wait 2–3 minutes. Confirm collector pods are `Running` and re-test the HEC endpoint with the `curl` command from Step 4.4.

---

## 12. Build Kubernetes Monitoring Dashboards

### Step 12.1 — Open the Dashboard Studio

1. In Splunk Enterprise, click **Dashboards** in the left navigation.
2. Click **Create New Dashboard**.
3. Title: `Kubernetes Workshop Overview`
4. Choose **Dashboard Studio**.
5. Click **Create**.

### Step 12.2 — Add a Pod Count Panel

- Visualization: **Single Value**
- Search:
  ```
  index=k8s_logs
  | stats dc(pod) AS "Running Pods"
  ```
- Title: `Total Active Pods`

### Step 12.3 — Add a Log Volume Over Time Panel

- Visualization: **Line Chart**
- Search:
  ```
  index=k8s_logs
  | timechart span=1m count AS "Log Events" by namespace
  ```
- Title: `Log Volume by Namespace`

### Step 12.4 — Add a Node CPU Metrics Panel

- Visualization: **Line Chart**
- Search:
  ```
  index=k8s_metrics metric_name=k8s.node.cpu.utilization
  | timechart span=1m avg(value) AS "CPU Utilization" by k8s.node.name
  ```
- Title: `Node CPU Utilization`

### Step 12.5 — Add an Error Log Panel

- Visualization: **Table**
- Search:
  ```
  index=k8s_logs (log=*error* OR log=*Error* OR log=*ERROR*)
  | table _time, namespace, pod, container, log
  | sort -_time
  | head 50
  ```
- Title: `Recent Error Logs`

### Step 12.6 — Add a Kubernetes Events Panel

- Visualization: **Table**
- Search:
  ```
  index=k8s_logs sourcetype=kube:events
  | eval message=coalesce(message, log)
  | table _time, namespace, reason, message
  | sort -_time
  | head 30
  ```
- Title: `Kubernetes Events`

### Step 12.7 — Save the Dashboard

Click **Save** (top right). The dashboard will auto-refresh as new data arrives.

---

## 13. Set Up Alerts

### Step 13.1 — Create a Pod Crash Loop Alert

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

### Step 13.2 — Create a High Log Volume Alert

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

### Step 13.3 — View Triggered Alerts

Go to **Activity → Triggered Alerts** in the Splunk Enterprise navigation to see any fired alerts.

---

## 14. Troubleshooting

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

### Collector Pods in CrashLoopBackOff

```bash
kubectl describe pod <pod-name> -n splunk-monitoring
kubectl logs <pod-name> -n splunk-monitoring --previous
```

Common causes:
- **Wrong HEC token** — verify the token matches what was created in Step 4.3
- **Wrong endpoint URL** — confirm the IP and port `8088` are reachable from within the KinD cluster
- **Firewall blocking port 8088** — ensure `firewall-cmd` rules were applied (Step 3.6)

To apply changes after editing the values file:

```bash
helm upgrade splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  --namespace splunk-monitoring \
  --values splunk-otel-values.yaml \
  --set splunkPlatform.token=<YOUR-HEC-TOKEN>
```

### HEC Endpoint Not Reachable from KinD

KinD containers run in Docker's internal network. The `localhost` or `127.0.0.1` of your host is **not** automatically reachable from inside KinD pods. Use one of:

```bash
# Find your host IP reachable from Docker containers
ip route | grep docker
# Or use Docker bridge IP (usually 172.17.0.1)
```

Update the `endpoint` in `splunk-otel-values.yaml` to use this IP, then run `helm upgrade`.

### No Data in Splunk Search

1. Confirm pods are `Running`.
2. Check collector logs for errors:
   ```bash
   kubectl logs -n splunk-monitoring \
     -l app=splunk-otel-collector,component=otel-collector-agent \
     --tail=100 | grep -i "error\|warn\|fail"
   ```
3. Test HEC directly:
   ```bash
   curl http://<YOUR-SERVER-IP>:8088/services/collector/event \
     -H "Authorization: Splunk <YOUR-HEC-TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{"event": "test", "index": "k8s_logs"}'
   ```
   Expected: `{"text":"Success","code":0}`
4. Verify `k8s_logs` and `k8s_metrics` indexes exist under **Settings → Indexes**.

### Helm Release Stuck

```bash
helm uninstall splunk-otel-collector -n splunk-monitoring
kubectl get pods -n splunk-monitoring -w   # wait for termination

helm install splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  --namespace splunk-monitoring \
  --values splunk-otel-values.yaml \
  --set splunkPlatform.token=<YOUR-HEC-TOKEN>
```

---

## 15. Clean Up

### Step 15.1 — Uninstall the Helm Release

```bash
helm uninstall splunk-otel-collector -n splunk-monitoring
```

### Step 15.2 — Delete the KinD Cluster

```bash
kind delete cluster --name splunk-workshop
```

Expected output:

```
Deleting cluster "splunk-workshop" ...
Deleted nodes: ["splunk-workshop-control-plane" "splunk-workshop-worker" "splunk-workshop-worker2"]
```

### Step 15.3 — Verify Docker Cleanup

```bash
docker ps | grep splunk-workshop
# Should return no results
```

### Step 15.4 — Remove Local Files (Optional)

```bash
rm kind-cluster.yaml splunk-otel-values.yaml
```

### Step 15.5 — Stop Splunk Enterprise (Optional)

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
3. Enabled the **HTTP Event Collector (HEC)** and created a token for secure ingestion
4. Created a **multi-node KinD cluster** using a config file
5. Deployed the **Splunk OpenTelemetry Collector** as a DaemonSet using Helm, pointing it at your local Splunk Enterprise HEC endpoint
6. Deployed a **sample nginx application** and generated log traffic
7. Verified **data flow** using Splunk Enterprise search
8. Built a **custom dashboard** with pod counts, log volume, CPU metrics, and events
9. Configured **alerts** for crash loops and high log volume

---

## Further Reading

- [Splunk OTel Collector for Kubernetes — GitHub](https://github.com/signalfx/splunk-otel-collector-chart)
- [Splunk Enterprise Documentation](https://docs.splunk.com/Documentation/Splunk)
- [Splunk Enterprise 10.4.0 Release Notes](https://docs.splunk.com/Documentation/Splunk/10.4.0/ReleaseNotes)
- [KinD Official Documentation](https://kind.sigs.k8s.io/)
- [Splunk Search Processing Language (SPL) Reference](https://docs.splunk.com/Documentation/Splunk/latest/SearchReference/WhatsInThisManual)
- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)

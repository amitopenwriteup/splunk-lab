# Workshop: Splunk Cloud + Kubernetes (KinD) Monitoring

> **Level:** Intermediate  
> **Duration:** ~3–4 hours  
> **Environment:** Local machine running KinD (Kubernetes in Docker)  
> **Goal:** Set up Splunk Cloud, deploy the Splunk OpenTelemetry Collector and Splunk Connect for Kubernetes into a local KinD cluster, and build dashboards to monitor your Kubernetes environment.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Architecture Overview](#2-architecture-overview)
3. [Set Up Your Splunk Cloud Trial Account](#3-set-up-your-splunk-cloud-trial-account)
4. [Configure Splunk Cloud — Indexes and HEC Token](#4-configure-splunk-cloud--indexes-and-hec-token)
5. [Install and Verify KinD](#5-install-and-verify-kind)
6. [Create a KinD Cluster](#6-create-a-kind-cluster)
7. [Install kubectl and Verify Cluster Access](#7-install-kubectl-and-verify-cluster-access)
8. [Install Helm](#8-install-helm)
9. [Deploy Splunk OpenTelemetry Collector for Kubernetes](#9-deploy-splunk-opentelemetry-collector-for-kubernetes)
10. [Deploy a Sample Application](#10-deploy-a-sample-application)
11. [Verify Data Flow into Splunk Cloud](#11-verify-data-flow-into-splunk-cloud)
12. [Build Kubernetes Monitoring Dashboards](#12-build-kubernetes-monitoring-dashboards)
13. [Set Up Alerts](#13-set-up-alerts)
14. [Explore Kubernetes Navigator (Infrastructure Monitoring)](#14-explore-kubernetes-navigator-infrastructure-monitoring)
15. [Troubleshooting](#15-troubleshooting)
16. [Clean Up](#16-clean-up)

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
| A web browser | Any modern browser | Splunk Cloud UI |

### Hardware Recommendations

- **CPU:** 4 cores minimum (6+ recommended)
- **RAM:** 8 GB minimum (16 GB recommended)
- **Disk:** 20 GB free space

### Accounts Required

- A valid email address to register for Splunk Cloud trial (free, no credit card needed)

### Check Docker is Running

Open a terminal and run:

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
│                   HTTPS / HEC                   │
└────────────────────────┼────────────────────────┘
                         │
                         ▼
              ┌─────────────────────┐
              │   Splunk Cloud      │
              │   (Trial Instance)  │
              │                     │
              │  - Log Search       │
              │  - Dashboards       │
              │  - Alerts           │
              │  - K8s Navigator    │
              └─────────────────────┘
```

**Data flow:**
1. The Splunk OTel Collector runs as a DaemonSet on every node in your KinD cluster.
2. It scrapes container logs, node metrics, and Kubernetes API events.
3. It forwards all data over HTTPS to your Splunk Cloud instance using the HTTP Event Collector (HEC) endpoint.
4. You search, visualize, and alert on that data inside Splunk Cloud.

---

## 3. Set Up Your Splunk Cloud Trial Account

### Step 3.1 — Register for a Free Trial

1. Open your browser and navigate to: **https://www.splunk.com/en_us/download/splunk-cloud.html**
2. Click **Start Free Trial**.
3. Fill in the registration form:
   - First Name, Last Name
   - Work Email (use a real email — you'll need to verify it)
   - Company Name
   - Phone Number (optional)
4. Accept the Terms of Service and click **Create Account**.
5. Check your email inbox for a verification message from Splunk.
6. Click the verification link in the email.

### Step 3.2 — Provision Your Splunk Cloud Instance

After verifying your email:

1. You will be redirected to the Splunk Cloud provisioning page.
2. Select your **region** (choose the one closest to you geographically).
3. Splunk will provision your trial instance. This typically takes **2–5 minutes**.
4. Once ready, you will receive a second email with your instance details:
   - **Instance URL** — looks like `https://<your-instance-name>.splunkcloud.com`
   - **Admin username** — typically `admin`
   - **Temporary password** — you will be asked to change this on first login

### Step 3.3 — First Login

1. Navigate to your instance URL from the provisioning email.
2. Log in with the admin credentials provided.
3. When prompted, **change your password** to something secure. Store it safely.
4. Dismiss any onboarding wizards or tour prompts for now — you will configure things manually in this workshop.

> **Note:** Splunk Cloud trials are valid for **14 days** with a **5 GB/day** ingest limit. This is more than sufficient for this workshop.

---

## 4. Configure Splunk Cloud — Indexes and HEC Token

You need to create a dedicated index to store Kubernetes data and an HTTP Event Collector (HEC) token so the collector can send data in.

### Step 4.1 — Create a Kubernetes Index

1. In Splunk Cloud, click the **Settings** menu in the top navigation bar.
2. Under the **Data** section, click **Indexes**.
3. Click the **New Index** button (top right).
4. Fill in the form:
   - **Index Name:** `k8s_logs`
   - **Index Data Type:** Events
   - **Max Size of Entire Index:** Leave at default (for trial)
   - **Frozen Path:** Leave blank
5. Click **Save**.

Repeat the process to create a second index:

- **Index Name:** `k8s_metrics`
- **Index Data Type:** Metrics

You should now have two new indexes: `k8s_logs` and `k8s_metrics`.

### Step 4.2 — Enable the HTTP Event Collector

1. Go to **Settings → Data Inputs**.
2. In the list, find **HTTP Event Collector** and click on it.
3. At the top right, click **Global Settings**.
4. Set **All Tokens** to **Enabled**.
5. Make note of or set the **HTTP Port Number** — default is `8088`.
6. Click **Save**.

### Step 4.3 — Create an HEC Token

1. Still on the HTTP Event Collector page, click **New Token**.
2. **Name:** `kubernetes-collector`
3. Click **Next**.
4. On the **Input Settings** page:
   - Under **Allowed Indexes**, add both `k8s_logs` and `k8s_metrics`.
   - Set **Default Index** to `k8s_logs`.
5. Click **Review**, then **Submit**.
6. On the confirmation screen, you will see your token value — it looks like:

   ```
   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
   ```

7. **Copy this token and save it somewhere safe.** You will need it in later steps. You cannot retrieve it again after closing this screen (but you can create a new one if needed).

### Step 4.4 — Note Your HEC Endpoint

Your HEC endpoint will be in this format:

```
https://<your-instance-name>.splunkcloud.com:8088/services/collector/event
```

For Splunk Cloud, the port is typically **8088** and it uses HTTPS. Make a note of this full URL.

> **Tip:** In Splunk Cloud trials, the HEC endpoint may use port `443` instead of `8088` on some instances. If port `8088` does not work in later steps, try port `443` with the same path.

---

## 5. Install and Verify KinD

If KinD is already installed, skip to Step 6.

### Step 5.1 — Install KinD on macOS

```bash
brew install kind
```

### Step 5.1 — Install KinD on Linux

```bash
# Download the latest KinD binary
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.23.0/kind-linux-amd64

# Make it executable
chmod +x ./kind

# Move to a location in your PATH
sudo mv ./kind /usr/local/bin/kind
```

### Step 5.1 — Install KinD on Windows

```powershell
# Using winget
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

You will create a multi-node KinD cluster with one control-plane node and two worker nodes. This gives you a more realistic Kubernetes environment to monitor.

### Step 6.1 — Create the Cluster Configuration File

Create a file named `kind-cluster.yaml` on your local machine with the following contents:

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

> **What this does:**
> - Creates a cluster named `splunk-workshop`
> - One control-plane node, two worker nodes
> - Mounts `/var/log` from host into worker nodes so the collector can read node logs
> - Exposes port 30000 on your host for accessing apps later

### Step 6.2 — Create the Cluster

```bash
kind create cluster --config kind-cluster.yaml
```

This will take **3–5 minutes**. You will see output like:

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
You can now use your cluster with:

kubectl cluster-info --context kind-splunk-workshop
```

### Step 6.3 — Verify the Cluster is Up

```bash
kubectl cluster-info --context kind-splunk-workshop
```

Expected output:

```
Kubernetes control plane is running at https://127.0.0.1:<port>
CoreDNS is running at https://127.0.0.1:<port>/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

---

## 7. Install kubectl and Verify Cluster Access

If `kubectl` is already installed, skip to Step 7.3.

### Step 7.1 — Install kubectl on macOS

```bash
brew install kubectl
```

### Step 7.1 — Install kubectl on Linux

```bash
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl
```

### Step 7.1 — Install kubectl on Windows

```powershell
winget install Kubernetes.kubectl
```

### Step 7.2 — Set the KinD Context

KinD automatically sets `kubectl` context when the cluster is created. Verify it is active:

```bash
kubectl config current-context
```

Expected output:

```
kind-splunk-workshop
```

If it shows a different context, switch to the KinD context:

```bash
kubectl config use-context kind-splunk-workshop
```

### Step 7.3 — Verify Node Status

```bash
kubectl get nodes
```

Expected output (all nodes should be `Ready`):

```
NAME                            STATUS   ROLES           AGE   VERSION
splunk-workshop-control-plane   Ready    control-plane   5m    v1.30.0
splunk-workshop-worker          Ready    <none>          4m    v1.30.0
splunk-workshop-worker2         Ready    <none>          4m    v1.30.0
```

### Step 7.4 — Verify System Pods

```bash
kubectl get pods -n kube-system
```

All pods should show `Running` or `Completed` status before proceeding.

---

## 8. Install Helm

Helm is used to install the Splunk OTel Collector chart.

### Step 8.1 — Install Helm on macOS

```bash
brew install helm
```

### Step 8.1 — Install Helm on Linux

```bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### Step 8.1 — Install Helm on Windows

```powershell
winget install Helm.Helm
```

### Step 8.2 — Verify Helm Installation

```bash
helm version
```

Expected output:

```
version.BuildInfo{Version:"v3.15.x", ...}
```

### Step 8.3 — Add the Splunk Helm Repository

```bash
helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart
```

Update the repo to fetch the latest chart versions:

```bash
helm repo update
```

Expected output:

```
Hang tight while we grab the latest from your chart repositories...
...Successfully got an update from the "splunk-otel-collector-chart" chart repository
Update Complete. ⎈Happy Helming!⎈
```

---

## 9. Deploy Splunk OpenTelemetry Collector for Kubernetes

### Step 9.1 — Create the Monitoring Namespace

It is good practice to deploy monitoring infrastructure in its own namespace:

```bash
kubectl create namespace splunk-monitoring
```

### Step 9.2 — Create a Secret for the HEC Token

Store your HEC token as a Kubernetes secret so it is not hardcoded in your Helm values:

```bash
kubectl create secret generic splunk-hec-secret \
  --from-literal=splunk_hec_token=<YOUR-HEC-TOKEN> \
  -n splunk-monitoring
```

Replace `<YOUR-HEC-TOKEN>` with the token value you copied in Step 4.3.

Verify the secret was created:

```bash
kubectl get secret splunk-hec-secret -n splunk-monitoring
```

### Step 9.3 — Create the Helm Values File

Create a file named `splunk-otel-values.yaml` with the following contents. Replace the placeholder values with your actual Splunk Cloud details:

```yaml
################################################################
# Splunk Platform (Splunk Cloud) connection settings
################################################################
splunkPlatform:
  # Your Splunk Cloud HEC endpoint
  endpoint: "https://<YOUR-INSTANCE>.splunkcloud.com:8088/services/collector/event"

  # Reference the secret created above
  token: ""  # leave blank — loaded from secret below

  # Target indexes
  index: "k8s_logs"
  metricsIndex: "k8s_metrics"

  # TLS settings — Splunk Cloud uses a valid certificate
  insecureSkipVerify: false

################################################################
# Cluster identification
################################################################
clusterName: "kind-splunk-workshop"

################################################################
# DaemonSet — runs on every node
################################################################
agent:
  enabled: true

  # Mount host paths for log collection
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

  # Resource limits suitable for a local KinD cluster
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
    # Exclude noisy system namespaces if desired
    excludeAgentLogs: true

################################################################
# Kubernetes events
################################################################
environment: "workshop"
```

> **Important:** Replace `<YOUR-INSTANCE>` in the endpoint URL with your actual Splunk Cloud instance name.

### Step 9.4 — Load the HEC Token into Helm Values

Instead of putting the token in plain text in the values file, you will pass it as a Helm set argument. First, retrieve it from the secret:

```bash
kubectl get secret splunk-hec-secret -n splunk-monitoring \
  -o jsonpath='{.data.splunk_hec_token}' | base64 --decode
```

Copy the output. You will use this in the install command below.

### Step 9.5 — Install the Splunk OTel Collector Chart

```bash
helm install splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  --namespace splunk-monitoring \
  --values splunk-otel-values.yaml \
  --set splunkPlatform.token=<YOUR-HEC-TOKEN>
```

Replace `<YOUR-HEC-TOKEN>` with your actual token value.

Expected output:

```
NAME: splunk-otel-collector
LAST DEPLOYED: <timestamp>
NAMESPACE: splunk-monitoring
STATUS: deployed
REVISION: 1
```

### Step 9.6 — Verify the Collector Pods are Running

Check that the DaemonSet pods started successfully:

```bash
kubectl get pods -n splunk-monitoring
```

You should see one `agent` pod per node (2 worker nodes = 2 agent pods) plus one `cluster-receiver` pod:

```
NAME                                                    READY   STATUS    RESTARTS   AGE
splunk-otel-collector-agent-abc12                       1/1     Running   0          2m
splunk-otel-collector-agent-def34                       1/1     Running   0          2m
splunk-otel-collector-k8s-cluster-receiver-xyz56        1/1     Running   0          2m
```

If any pods show `Error` or `CrashLoopBackOff`, see the [Troubleshooting](#15-troubleshooting) section.

### Step 9.7 — Check Collector Logs

Check the logs of one agent pod to confirm it is connecting to Splunk Cloud:

```bash
kubectl logs -n splunk-monitoring \
  -l app=splunk-otel-collector,component=otel-collector-agent \
  --tail=50
```

Look for lines indicating successful connections such as:

```
Everything is ready. Begin running and processing data.
```

If you see repeated connection errors, double-check your HEC endpoint URL and token.

---

## 10. Deploy a Sample Application

Deploy a simple nginx application so you have something meaningful to monitor.

### Step 10.1 — Create a Namespace for the App

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

All 3 pods should show `Running`:

```
NAME                          READY   STATUS    RESTARTS   AGE
nginx-demo-xxxxxxxxx-aaaaa    1/1     Running   0          1m
nginx-demo-xxxxxxxxx-bbbbb    1/1     Running   0          1m
nginx-demo-xxxxxxxxx-ccccc    1/1     Running   0          1m
```

### Step 10.5 — Generate Some Log Traffic

Get the nginx service NodePort:

```bash
kubectl get svc nginx-demo -n demo-app
```

Note the `NodePort` value (a number like `32456`). Then port-forward it:

```bash
kubectl port-forward svc/nginx-demo 8080:80 -n demo-app &
```

Now generate some requests:

```bash
for i in {1..20}; do curl -s http://localhost:8080 > /dev/null; done
```

These requests will generate access log entries that the collector will ship to Splunk Cloud.

---

## 11. Verify Data Flow into Splunk Cloud

### Step 11.1 — Open the Splunk Cloud Search Interface

1. In your Splunk Cloud browser tab, click **Search & Reporting** in the left navigation bar (or from the home screen).
2. You will be taken to the Search & Reporting app.

### Step 11.2 — Search for Kubernetes Logs

In the search bar, run the following search. Set the time range to **Last 15 minutes**:

```
index=k8s_logs
| head 20
```

Click the green **Search** button (or press Enter).

You should see log events appearing within a few seconds. Each event will have fields such as:
- `host` — the node the log came from
- `source` — the log file path
- `sourcetype` — e.g., `kube:container:nginx`
- `namespace` — the Kubernetes namespace
- `pod` — the pod name
- `container` — the container name

### Step 11.3 — Search for nginx Access Logs Specifically

```
index=k8s_logs namespace=demo-app container=nginx
| table _time, pod, log
```

You should see the nginx access log entries for the requests you generated.

### Step 11.4 — Search for Kubernetes Events

```
index=k8s_logs sourcetype=kube:events
| head 20
```

This shows Kubernetes cluster events such as pod scheduling, image pulls, and health checks.

### Step 11.5 — Search for Metrics

```
index=k8s_metrics
| head 20
```

You should see metric events with fields like `metric_name`, `k8s.node.name`, `k8s.namespace.name`, and numeric values.

> **If no data appears:** Wait 2–3 minutes for the collector to start sending. Also confirm the collector pods are `Running` and check their logs as described in Step 9.7.

---

## 12. Build Kubernetes Monitoring Dashboards

### Step 12.1 — Open the Dashboard Studio

1. In Splunk Cloud, click **Dashboards** in the left navigation.
2. Click **Create New Dashboard**.
3. Give it a title: `Kubernetes Workshop Overview`
4. Choose **Dashboard Studio** (the newer interface).
5. Click **Create**.

### Step 12.2 — Add a Pod Count Panel

1. Click **Add Panel** → **New**.
2. Choose **Single Value** as the visualization type.
3. In the search box, enter:

   ```
   index=k8s_logs
   | stats dc(pod) AS "Running Pods"
   ```

4. Set the time range to **Last 60 minutes**.
5. Click **Apply**.
6. Title the panel: `Total Active Pods`.

### Step 12.3 — Add a Log Volume Over Time Panel

1. Click **Add Panel** → **New**.
2. Choose **Line Chart**.
3. Enter the search:

   ```
   index=k8s_logs
   | timechart span=1m count AS "Log Events" by namespace
   ```

4. Set the time range to **Last 60 minutes**.
5. Click **Apply**.
6. Title the panel: `Log Volume by Namespace`.

### Step 12.4 — Add a Node CPU Metrics Panel

1. Click **Add Panel** → **New**.
2. Choose **Line Chart**.
3. Enter the search:

   ```
   index=k8s_metrics metric_name=k8s.node.cpu.utilization
   | timechart span=1m avg(value) AS "CPU Utilization" by k8s.node.name
   ```

4. Set time range to **Last 60 minutes**.
5. Click **Apply**.
6. Title the panel: `Node CPU Utilization`.

### Step 12.5 — Add an Error Log Panel

1. Click **Add Panel** → **New**.
2. Choose **Table**.
3. Enter the search:

   ```
   index=k8s_logs (log=*error* OR log=*Error* OR log=*ERROR*)
   | table _time, namespace, pod, container, log
   | sort -_time
   | head 50
   ```

4. Set time range to **Last 60 minutes**.
5. Click **Apply**.
6. Title the panel: `Recent Error Logs`.

### Step 12.6 — Add a Kubernetes Events Panel

1. Click **Add Panel** → **New**.
2. Choose **Table**.
3. Enter the search:

   ```
   index=k8s_logs sourcetype=kube:events
   | eval message=coalesce(message, log)
   | table _time, namespace, reason, message
   | sort -_time
   | head 30
   ```

4. Set time range to **Last 60 minutes**.
5. Click **Apply**.
6. Title the panel: `Kubernetes Events`.

### Step 12.7 — Save the Dashboard

1. Click **Save** (top right of the dashboard editor).
2. Your dashboard is now saved and will auto-refresh as new data arrives.

---

## 13. Set Up Alerts

### Step 13.1 — Create a Pod Crash Loop Alert

This alert will fire if any container restarts more than 5 times in 15 minutes.

1. Go to **Search & Reporting**.
2. Run the following search:

   ```
   index=k8s_logs sourcetype=kube:events reason=BackOff
   | stats count AS restart_count by namespace, pod
   | where restart_count > 5
   ```

3. Set the time range to **Last 15 minutes**.
4. Click **Save As** → **Alert**.
5. Configure the alert:
   - **Title:** `Pod CrashLoopBackOff Detected`
   - **Alert Type:** Scheduled
   - **Run Every:** 5 minutes
   - **Time Range:** Last 15 minutes
   - **Trigger Condition:** Number of Results → Greater than → 0
   - **Trigger Once:** Per-Result
6. Under **Trigger Actions**, click **Add Actions**.
7. Select **Send Email** (or **Add to Triggered Alerts** to keep it in the UI).
8. Click **Save**.

### Step 13.2 — Create a High Log Volume Alert

This alert fires if a namespace produces an unusual spike in log volume.

1. In Search & Reporting, run:

   ```
   index=k8s_logs
   | timechart span=5m count AS log_count by namespace
   | where log_count > 1000
   ```

2. Click **Save As** → **Alert**.
3. Configure:
   - **Title:** `High Log Volume in Namespace`
   - **Alert Type:** Scheduled
   - **Run Every:** 10 minutes
   - **Trigger Condition:** Number of Results → Greater than → 0
4. Add a trigger action and click **Save**.

### Step 13.3 — View Triggered Alerts

1. Go to **Activity** → **Triggered Alerts** in the Splunk Cloud navigation.
2. Any alert that has fired will appear here with details.

---

## 14. Explore Kubernetes Navigator (Infrastructure Monitoring)

If your Splunk Cloud trial includes **Infrastructure Monitoring** (Splunk Observability Cloud integration):

### Step 14.1 — Access Infrastructure Monitoring

1. In Splunk Cloud, click the **App** menu.
2. Look for **Infrastructure Monitoring** or **Splunk Observability**.
3. If available, click through to the Kubernetes Navigator.

### Step 14.2 — Navigate the Cluster View

The Kubernetes Navigator provides a visual, hierarchical view of your cluster:

1. Click **Infrastructure** in the left nav.
2. Select **Kubernetes** from the infrastructure types.
3. You should see your `kind-splunk-workshop` cluster listed.
4. Click on the cluster name to drill down into:
   - **Nodes** — CPU, memory, disk, and network per node
   - **Namespaces** — resource usage by namespace
   - **Workloads** — deployments, daemonsets, and their pod counts
   - **Pods** — individual pod health, restart counts, resource usage

### Step 14.3 — Use the Built-in Kubernetes Dashboards

Splunk provides pre-built dashboards for Kubernetes. Look for:

- **Kubernetes Nodes** — system-level metrics for each node
- **Kubernetes Pods** — per-pod CPU and memory
- **Kubernetes Deployments** — replica counts and rollout status

These are populated automatically once the collector is running.

---

## 15. Troubleshooting

### Collector Pods in CrashLoopBackOff

```bash
# Get detailed pod info
kubectl describe pod <pod-name> -n splunk-monitoring

# Get logs from the crashed container
kubectl logs <pod-name> -n splunk-monitoring --previous
```

Common causes:
- **Wrong HEC token** — verify the token matches what was created in Splunk Cloud
- **Wrong endpoint URL** — ensure the full URL including port and path is correct
- **TLS issues** — try setting `insecureSkipVerify: true` temporarily in the values file to rule out cert issues

To apply changes to the Helm release after editing your values file:

```bash
helm upgrade splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  --namespace splunk-monitoring \
  --values splunk-otel-values.yaml \
  --set splunkPlatform.token=<YOUR-HEC-TOKEN>
```

### No Data in Splunk Cloud Search

1. Confirm collector pods are `Running` (not just `Pending`).
2. Check collector logs for connection errors:

   ```bash
   kubectl logs -n splunk-monitoring \
     -l app=splunk-otel-collector,component=otel-collector-agent \
     --tail=100 | grep -i "error\|warn\|fail"
   ```

3. Verify the HEC token and endpoint in Splunk Cloud are correct.
4. Test the HEC endpoint directly with curl from your local machine:

   ```bash
   curl -k https://<YOUR-INSTANCE>.splunkcloud.com:8088/services/collector/event \
     -H "Authorization: Splunk <YOUR-HEC-TOKEN>" \
     -H "Content-Type: application/json" \
     -d '{"event": "test from workshop", "index": "k8s_logs"}'
   ```

   Expected response: `{"text":"Success","code":0}`

5. Check if the `k8s_logs` and `k8s_metrics` indexes exist in Splunk Cloud Settings.

### KinD Cluster Unreachable

```bash
# Check if Docker containers are running
docker ps | grep splunk-workshop

# Check cluster status
kubectl cluster-info dump | head -20
```

If nodes are `NotReady`:

```bash
kubectl describe node <node-name>
```

Look at the `Conditions` section for the root cause.

### Helm Release Stuck

To uninstall and reinstall from scratch:

```bash
helm uninstall splunk-otel-collector -n splunk-monitoring

# Wait for all pods to terminate
kubectl get pods -n splunk-monitoring -w

# Reinstall
helm install splunk-otel-collector \
  splunk-otel-collector-chart/splunk-otel-collector \
  --namespace splunk-monitoring \
  --values splunk-otel-values.yaml \
  --set splunkPlatform.token=<YOUR-HEC-TOKEN>
```

---

## 16. Clean Up

When you are finished with the workshop, clean up all local resources.

### Step 16.1 — Uninstall the Helm Release

```bash
helm uninstall splunk-otel-collector -n splunk-monitoring
```

### Step 16.2 — Delete the KinD Cluster

This removes all Docker containers, volumes, and network resources created by KinD:

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
```

This should return no results.

### Step 16.4 — Remove Local Files (Optional)

```bash
rm kind-cluster.yaml splunk-otel-values.yaml
```

### Step 16.5 — Splunk Cloud Trial

Your Splunk Cloud trial will automatically expire after 14 days. If you want to remove your data indexes before then:

1. Go to **Settings → Indexes** in Splunk Cloud.
2. Click **Delete** next to `k8s_logs` and `k8s_metrics`.

---

## Summary

In this workshop you:

1. Registered for a **Splunk Cloud trial** and provisioned your instance
2. Created **dedicated indexes** for Kubernetes logs and metrics
3. Set up an **HEC token** for secure data ingestion
4. Created a **multi-node KinD cluster** using a config file
5. Deployed the **Splunk OpenTelemetry Collector** as a DaemonSet using Helm
6. Deployed a **sample nginx application** and generated log traffic
7. Verified **data flow** using Splunk Cloud search
8. Built a **custom dashboard** with pod counts, log volume, CPU metrics, and events
9. Configured **alerts** for crash loops and high log volume
10. Explored the **Kubernetes Navigator** for visual cluster monitoring

---

## Further Reading

- [Splunk OTel Collector for Kubernetes — GitHub](https://github.com/signalfx/splunk-otel-collector-chart)
- [Splunk Cloud Documentation](https://docs.splunk.com/Documentation/SplunkCloud)
- [KinD Official Documentation](https://kind.sigs.k8s.io/)
- [Splunk Search Processing Language (SPL) Reference](https://docs.splunk.com/Documentation/Splunk/latest/SearchReference/WhatsInThisManual)
- [OpenTelemetry Collector Documentation](https://opentelemetry.io/docs/collector/)

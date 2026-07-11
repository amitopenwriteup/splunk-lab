# Module 
## The Kubernetes Integration

**Estimated time:** 60–70 minutes
**Environment:** Splunk Observability Cloud UI + Kubernetes cluster (kubectl/Helm access required)

---

### Learning Objectives
By the end of this workshop, you will be able to:
- Explain the value and purpose of the OpenTelemetry project
- Install the Splunk OpenTelemetry Collector using the install wizard
- Describe how the Observability Cloud collects Kubernetes data
- Identify the components of the Splunk Kubernetes integration

---

### Pre-Lab Discussion: OpenTelemetry as the Data Backbone
OpenTelemetry (OTel) is a vendor-neutral, open standard for collecting telemetry data (metrics, traces, and logs). Splunk Observability Cloud is built on OTel. Discuss:
- Why would an organization prefer a vendor-neutral collection standard over a proprietary agent?
- What is the difference between a "push" and a "pull" telemetry collection model?

---

### Lab 2.1 — Installing the Splunk OpenTelemetry Collector
**Goal:** Use the install wizard to deploy the collector into a Kubernetes cluster.

1. In Splunk Observability Cloud, click **Data Management** in the left navigation sidebar (or click **Getting Started** if this is a brand-new org).
2. On the Data Management page, click the **Add Integration** button (usually top-right of the screen).
3. In the integration catalog/search box, type `Kubernetes` and press Enter.
4. Click the **Kubernetes** tile from the search results to open the integration setup wizard.
5. On the **Install Configuration** screen, fill in the following fields:
   - **Platform** — confirm the dropdown is set to **Kubernetes** (pre-filled).
   - **Splunk Observability access token** — click the dropdown and select an existing token (e.g., `linux-otel`), or generate a new one if none exists.
   - **Provider** — click the dropdown and select your infrastructure provider (e.g., AWS, GCP, Azure). If none apply, leave it set to **Other**.
   - **Distribution** — click the dropdown and select your Kubernetes distribution (e.g., EKS, GKE, AKS, OpenShift). If none apply, leave it set to **Other**.
   - **Cluster name** — type a name to identify this cluster in Splunk Observability Cloud (e.g., `k8s-cluster`). This is how the cluster will appear in the Navigator later.
   - **Log collection** — click the dropdown and choose whether to enable log collection alongside metrics. Select **No log collection** if you only want metrics for this module, or choose a log collection option if your environment requires it.
6. Click **Next** at the bottom of the screen to proceed to the next configuration step (installation method: Helm or manifest). Use **Back** if you need to revisit any field above.
7. On the following screen, choose your installation method:
   - Click the **Helm** tab if you plan to install via Helm chart, or
   - Click the **YAML Manifest** tab if you plan to apply a manifest directly.
8. Review the auto-generated Helm `values.yaml` snippet or manifest shown in the wizard's code panel — it will already reflect the Platform, token, Provider, Distribution, Cluster name, and Log collection settings you selected in step 5.
9. Click the **Copy** icon next to the code panel to copy the install command/manifest to your clipboard.
10. Open a terminal with `kubectl`/`helm` access to your target cluster.
11. If using Helm, add the Splunk OTel Collector chart repo (if not already added):
    ```
    helm repo add splunk-otel-collector-chart https://signalfx.github.io/splunk-otel-collector-chart
    helm repo update
    ```
12. Paste and run the install command copied from the wizard, for example:
    ```
    helm install splunk-otel-collector splunk-otel-collector-chart/splunk-otel-collector \
      -f values.yaml
    ```
13. Wait for the Helm install to complete (you should see a "STATUS: deployed" message).
14. Verify the collector pods are running:
    ```
    kubectl get pods -n <otel-namespace>
    ```
15. Confirm all listed pods show `Running` status and `1/1` or `2/2` in the READY column (no `CrashLoopBackOff` or `Pending` states).

**Checkpoint:** Confirm all collector pods show `Running` status before continuing.

---

### Lab 2.2 — Tracing the Data Path
**Goal:** Understand how data flows from your cluster into Splunk Observability Cloud.

1. In your terminal, list the collector's DaemonSet pods specifically:
   ```
   kubectl get pods -n <otel-namespace> -l app=splunk-otel-collector-agent
   ```
   Confirm there is one agent pod per node.
2. List the cluster receiver deployment pod:
   ```
   kubectl get pods -n <otel-namespace> -l app=splunk-otel-collector-k8s-cluster-receiver
   ```
   Confirm there is exactly one pod for this component.
3. Open the Helm `values.yaml` file you used for install in a text editor.
4. Locate the `agent:` section — this configures the DaemonSet responsible for node/pod/container metrics.
5. Locate the `clusterReceiver:` section — this configures the single Deployment responsible for cluster-wide/API-server-level data.
6. On paper or in a shared doc, sketch the data flow:
   `Kubernetes API / kubelet → OTel Collector (agent + cluster receiver) → Splunk Observability Cloud ingest`

**Checkpoint:** Which deployment mode would you check first if a single node's metrics were missing? Which mode would you check if cluster-wide metrics (e.g., total pod count) were missing?

---

### Lab 2.3 — Identifying Integration Components
**Goal:** Confirm the integration is complete and identify its supporting pieces.

1. Return to the Splunk Observability Cloud UI in your browser.
2. Click **Kubernetes** in the left sidebar, then click **Navigator**.
3. Click the cluster selector dropdown at the top and confirm your newly integrated cluster now appears in the list.
4. Select your cluster from the dropdown — the map view should populate with live node/pod tiles within a few minutes of a successful install.
5. In your terminal, list all pods in the OTel namespace to identify supporting components:
   ```
   kubectl get pods -n <otel-namespace>
   ```
6. Identify pods related to:
   - `kube-state-metrics` (cluster object state metrics)
   - Node-level log collection agents (if logs were enabled in the wizard)
7. Back in the browser, click **Data Management** in the sidebar.
8. Click on your Kubernetes integration entry in the list.
9. Review the **Status** column/indicator — confirm it shows "Healthy" or "Receiving Data."
10. Click **View Details** (if available) to see last-seen timestamps for incoming data.

**Checkpoint:** Is your cluster showing "healthy"/active data flow in the UI? If not, what would you check first?

---

### Module 2 Knowledge Check
1. What problem does OpenTelemetry solve for observability tooling?
2. What are the two primary collector deployment modes in a Kubernetes cluster, and what does each one collect?
3. How would you verify that the Kubernetes integration is successfully sending data to Splunk Observability Cloud?
4. Name two supporting components that get installed alongside the core OTel Collector.

---

**Next:** Proceed to Module 3 — Monitoring Kubernetes with Built-in Content.

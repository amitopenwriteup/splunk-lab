# Splunk Observability Cloud Lab: Kubernetes Dashboard, Detector & Notifications

This lab builds a Kubernetes dashboard entirely through the UI (Plot Editor + Browse), adds a detector that alerts on sustained conditions over a 2-hour window, wires up a notification, and finishes with import, export, and clone.

**Assumes:** Kubernetes is already deployed and sending data via the Splunk Distribution of the OpenTelemetry Collector.

---

## Part 1 — Create the Dashboard (using navigation, not raw queries)

1. From the Splunk Observability Cloud home page, select **Dashboards**.
2. Click **Create (+) > New Dashboard**.
3. Choose a dashboard group (your personal **User** group works for this lab) and name it `Kubernetes Cluster Overview`.
4. Click **Add Chart > New Chart**. This opens the chart builder shown in the **Plot Editor** tab.

### Build each chart via the UI

For every chart below, repeat this same navigation pattern:

1. In the **Plot editor** tab, click into the **Metric or event** field for Plot A.
2. Click **Browse** to open the metric picker instead of typing a SignalFlow query.
3. Search for the metric name (see table below) and select it from the list.
4. Use the **Filter** row (or the **Overrides: Filter** box at the top) to scope by dimension — e.g., click **+ Add filter**, choose `k8s.node.name`, `k8s.cluster.name`, or `k8s.namespace.name`, and pick a value or wildcard.
5. Use the **F(x)** column to add an aggregation (e.g., **Mean by**, **Sum by**, **Latest**) and pick the "by" dimension (e.g., `k8s.node.name`).
6. Type a friendly label in the **Name** column (e.g., "CPU Utilization by Node").
7. Choose the chart type from the icon row above the plot area (line, column, heatmap, list, single value).
8. Click **Save and close**.

| Chart | Metric to browse for | Suggested aggregation | Suggested "by" dimension |
|---|---|---|---|
| CPU utilization by node | `cpu.utilization` | Mean by | `k8s.node.name` |
| Memory utilization by node | `memory.utilization` | Mean by | `k8s.node.name` |
| Node readiness | `k8s.node.condition_ready` | Latest by | `k8s.node.name` |
| Container restarts | `k8s.container.restarts` | Sum by | `k8s.pod.name`, `k8s.namespace.name` |
| Pod status reasons | `k8s.pod.status_reason` | Latest by | `k8s.pod.name`, `k8s.namespace.name` |
| Deployment: desired replicas | `k8s.deployment.desired` | Mean by | `k8s.deployment.name` |
| Deployment: available replicas | `k8s.deployment.available` | Mean by | `k8s.deployment.name` |
| Disk utilization by node | `disk.utilization` | Mean by | `k8s.node.name` |
| Network traffic by node | `network.total` | Sum by | `k8s.node.name` |
| CPU limit vs. request | `k8s.container.cpu_limit`, `k8s.container.cpu_request` | Sum by | `k8s.namespace.name` |

> Tip: If you see a **"Different dimension keysets were detected"** warning, use the **+ Add filter** row to exclude the conflicting series — for example, add a filter on `k8s.container.name` set to **"is not"** any value, so only pure node-level series remain.

> Tip: Click **View SignalFlow** (top right of the Plot editor) at any point to see the query the UI generated for you — useful for learning the syntax without having to write it by hand.

9. Once all charts are added, drag tiles in the dashboard edit view to arrange them, then click **Done editing** and **Save**.

---

## Part 2 — Create a Detector (Alert) with a 2-Hour Condition

This creates an alert that only fires if a condition holds for a sustained 2-hour period — useful for avoiding noisy, short-lived blips (e.g., a node briefly spiking CPU during a deploy).

1. Open one of your dashboard charts — e.g., **CPU Utilization by Node**.
2. Click the chart's **Actions (⋯)** menu (or the bell icon if visible) and select **Create Detector** (alternatively, go to **Alerts & Detectors > New Detector** from the main menu and pick the metric from there).
3. In **New Detector**, confirm or adjust the **Signal**: it should default to the metric/filter you already built (e.g., `cpu.utilization` by `k8s.node.name`).
4. Click **Proceed to Alert Condition**.
5. Choose an alert condition type — for this lab, use **Static Threshold**.
6. Set the threshold value (e.g., "above 80%").
7. Find the **Trigger sensitivity** / **Alert if true for** setting and set the duration to **2 hours**. This means the condition must remain true continuously for 2 hours before the detector fires — filtering out short spikes.
8. Give the alert rule a clear name, e.g., `K8s Node - Sustained High CPU (2h)`.
9. Click **Proceed to Notifications**.

### Set up the notification

1. In the **Notifications** step, click **Add Notification**.
2. Choose a channel: **Email**, **Slack**, **PagerDuty**, **Webhook**, etc.
3. For email, enter the recipient address(es); for Slack/PagerDuty, select the connected integration and channel/service.
4. Optionally add a **Runbook URL** and custom message text so responders know what to do.
5. Click **Save Detector**.

Your detector is now live and will notify the configured channel only if CPU utilization stays above threshold for 2 hours straight.

---

## Part 3 — Import, Export, and Clone

### Import a dashboard
1. Select **Dashboard** from the home page, click **Create (+)**.
2. If inside a dashboard group: **Import > Dashboard**. If not: **Import > Dashboard Group** first, then pick the dashboard.
3. Choose the JSON file from your local workstation and confirm.

### Export a dashboard
1. Navigate to the dashboard you want to export.
2. Click **Dashboard actions (⋯) > Export > Download**. This produces a JSON file you can back up, version-control, or hand to another org/team.
3. To export an entire group instead, use the **Dashboard Group actions (⋯)** menu the same way.

### Clone a dashboard
1. Open the dashboard (your custom one, or a **Built-in > Kubernetes** dashboard).
2. Click **Dashboard actions (⋯) > Save As…**.
3. Give it a new name, choose an existing custom/user dashboard group or create a new one, and save.
4. The clone is fully editable, even if the source was a read-only built-in dashboard.

---

## Lab Recap

| Task | Where | Key action |
|---|---|---|
| Build dashboard via UI | Add Chart > Plot editor | Browse metric, add filter, set F(x), name plot |
| Create detector | Chart actions (⋯) > Create Detector | Static threshold, 2h sustained trigger |
| Set notification | Detector wizard > Notifications | Add Notification (email/Slack/PagerDuty) |
| Import | Dashboards > Create (+) > Import | Upload JSON |
| Export | Dashboard actions (⋯) | Export > Download |
| Clone | Dashboard actions (⋯) | Save As… into a group |

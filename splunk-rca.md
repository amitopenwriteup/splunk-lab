# Splunk Observability Cloud: Anomaly Detection, Alerting & Root Cause Analysis

This reference covers four related capabilities in Splunk Observability Cloud that work together to detect issues, reduce noise, route the right alerts to the right people, and speed up root cause identification.

---

## 1. Anomaly Detection

Splunk Observability Cloud detects anomalies using **built-in alert conditions** on detectors, rather than requiring you to hand-tune static thresholds for every signal. The main anomaly-oriented conditions are:

| Condition | What it does | Best for |
|---|---|---|
| **Historical Anomaly** | Compares a signal's current behavior to its own historical pattern over a comparable prior period | Metrics with strong daily/weekly seasonality (e.g., request rate that's naturally higher on weekdays) |
| **Sudden Change** | Detects a rapid shift in a signal relative to its own recent behavior | Catching spikes/drops as they happen, without waiting on a long historical baseline |
| **Outlier Detection** | Compares a signal to its peers in the same population during the same time window | Identifying inconsistent behavior among a population of emitters, such as which node in a cluster is using more CPU than the others |
| **Resource Running Out** | Projects forward from current trend to flag when a resource will be exhausted | Disk space, connection pools, quota limits |
| **Heartbeat Check** | Alerts when expected data stops arriving | Detecting silent failures, dead agents, or broken pipelines |
| **Static Threshold** | Classic fixed threshold | Well-understood metrics with a known safe/unsafe boundary |

**Key distinction:** to compare current signal values to past values of the same signal, use Sudden Change or Historical Anomaly; use Outlier Detection instead when you want to compare a signal against its peers rather than its own history.

### Where to configure it
1. Go to **Alerts & Detectors > New Detector** (or create one from a chart's actions menu).
2. Pick your signal, then choose one of the conditions above instead of a plain static threshold.
3. Tune sensitivity/duration so the alert only fires on meaningful deviations, not noise.

---

## 2. Common Alerting "Problem" Scenarios

Rather than a single feature called "Problem," Observability Cloud's built-in conditions are explicitly designed around recurring **problem scenarios** operators run into:

- **"Did a host silently drop out of rotation?"** → Outlier Detection or Heartbeat Check
- **"Are we about to run out of disk/memory/connections?"** → Resource Running Out
- **"Did latency or error rate just spike?"** → Sudden Change
- **"Is this normal for a Monday morning, or actually abnormal?"** → Historical Anomaly
- **"Is one node/pod behaving differently from its peers?"** → Outlier Detection

Framing detector creation around "what problem am I trying to catch" (rather than "what metric do I have") is the recommended approach — pick the scenario first, then let that point you to the right condition type.

---

## 3. Alerting Profiles (Severity, Routing & Notifications)

Once a detector's condition triggers, Observability Cloud gives you several controls that function like an "alerting profile" — determining **how loud**, **to whom**, and **how often** an alert surfaces:

### Severity
Each alert rule within a detector has a **severity** level (e.g., Critical, Major, Minor, Warning, Info). Severity controls how the alert is displayed on the Active Alerts page and can determine downstream routing in your incident tool.

### Notifications
For each alert rule, add one or more notification recipients/channels:
- Email
- Slack
- PagerDuty / Opsgenie / VictorOps
- Webhook
- ServiceNow, Jira, and other integrations

You can attach different notification targets to different severities on the *same* detector — e.g., Critical → PagerDuty + Slack, Warning → email only.

### Muting rules
Use **mute rules** to temporarily silence notifications for a detector, a set of detectors, or all alerts matching certain dimensions (e.g., during planned maintenance on a specific cluster), without disabling the underlying detection.

### AutoDetect alerts and detectors
Splunk Observability Cloud auto-creates a starter set of detectors when it recognizes a supported integration (e.g., a new Kubernetes cluster or APM service). You can copy and customize these AutoDetect detectors instead of building from scratch, then subscribe, mute, or turn off their notifications individually.

### Steps to set an alerting profile on a detector
1. Open (or create) a detector.
2. For each alert rule, set the **condition** (see Section 1) and **severity**.
3. Click **Add Notification** and choose the channel(s) for that severity.
4. Optionally attach a **runbook URL** so responders have a starting action.
5. Save and activate.

---

## 4. Root Cause Analysis

When alerts relate to **Splunk APM services** or **Kubernetes infrastructure**, Splunk Observability Cloud can automatically kick off AI-assisted root cause analysis:

- The AI troubleshooting agent refers to root cause analysis powered by Splunk AI. Alerts and detectors determine whether services and infrastructure components are healthy or not, then for alerts relating to Splunk APM services and Kubernetes in Infrastructure Monitoring, Splunk Observability Cloud automatically triggers the AI troubleshooting agent to do root cause analysis and display suspected root causes when the user accesses the alert.
- From an alert, select **Review root causes** on the Overview tab, then open the **Root Cause Analysis** tab to inspect the specific suspected cause.
- Beyond root causes, the same agent can generate an **AI remediation plan** — guided next steps to resolve the underlying issue.

> Availability note: the AI troubleshooting agent and remediation plan is currently available only to customers in the us1 realm of Splunk Observability Cloud; reach out to your Splunk representative if you're on a different realm and want access.

### Typical root cause workflow
1. A detector alert fires (from Section 1/3).
2. Open the alert from **Alerts > Active alerts**.
3. If it's an APM or Kubernetes-related alert, look for **Review root causes** on the alert's Overview tab.
4. Drill into the **Root Cause Analysis** tab to see the specific suspected cause(s) the AI surfaced.
5. Use the accompanying **remediation plan** (if available) for guided next steps.

---

## Quick Reference

| Capability | Where it lives | Purpose |
|---|---|---|
| Anomaly Detection | Detector condition types (Historical Anomaly, Sudden Change, Outlier Detection, etc.) | Catch deviations without hand-tuned static thresholds |
| Problem scenarios | Same detector conditions, framed by use case | Match the right condition to the operational question you're asking |
| Alerting profiles | Alert rule severity + notifications + mute rules | Control who gets notified, how loudly, and when to stay quiet |
| Root Cause Analysis | AI troubleshooting agent (APM & Kubernetes alerts) | Auto-surface suspected causes and a remediation plan from an active alert |

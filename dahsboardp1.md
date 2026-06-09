# Splunk Workshop

## Lab 11: Dashboards for Incident Response

- Build a P1 Incident Dashboard combining System + Application + Logs in one unified view
- Use time synchronization to align all panels to a specific incident start time
- Apply comparison views: Last 1h vs. previous hour and before/after deploy
- Correlate application metrics with infrastructure performance and log patterns
- Simulate a production incident and use your dashboard to identify root cause
- Reduce Mean Time To Resolution (MTTR) using dashboard-driven investigation

---

## Prerequisites

**Required**

- Splunk Enterprise or Splunk Cloud instance with admin or power user role
- Splunk Universal Forwarder installed on a host or Kubernetes cluster
- At least one instrumented application forwarding logs and metrics to Splunk
- Splunk Infrastructure Monitoring or Splunk ITSI (optional but helpful)
- kubectl configured (if using Kubernetes)

---

## Background: The Anatomy of an Incident Dashboard

During a production incident, engineers need to answer three questions fast:

- What is broken? (Symptoms — error rates, latency spikes)
- Where is it broken? (Scope — which service, host, region)
- Why did it break? (Cause — correlated logs, deploy events, resource exhaustion)

A well-designed incident dashboard answers all three by combining:

| Signal Type | What It Shows | Example Panels |
|---|---|---|
| System Metrics | Infrastructure health: CPU, memory, disk, network | CPU chart, memory usage, disk I/O |
| Application Metrics | Application health: latency, error rate, throughput | Error %, response time, request rate |
| Logs | Contextual evidence: error messages, stack traces, audit trail | Log stream, error log count, top errors |

**Why Unify All Three Signals?** Siloed tools — jumping between metrics, traces, and logs — add 10-20 minutes of cognitive overhead per incident. A unified dashboard lets you correlate: "CPU spiked at 14:32 -> App latency jumped at 14:33 -> error logs started at 14:33" in seconds, not minutes.

---

# Part 1: Lab Setup (15 minutes)

Make sure the service-map workload is running and forwarding data to Splunk before you proceed.

Wait 3-5 minutes for data to appear in Splunk after starting your forwarders.

**Verify Data is Flowing**

1. Navigate to Search and Reporting in Splunk
2. Run: `index=lab sourcetype=app_logs | head 10` — you should see application log events
3. Run: `index=lab sourcetype=os_metrics metric_name=cpu.usage | head 10` — confirms infrastructure metrics
4. Navigate to Dashboards and confirm your instance is accessible

---

# Part 2: Build Your P1 Incident Dashboard (45 minutes)

## Step 3: Create the Dashboard

A P1 (Priority 1) incident dashboard must provide immediate situational awareness. We will build it section by section.

- Navigate to Dashboards > Create New Dashboard
- Select Classic Dashboards (or Dashboard Studio for newer Splunk versions)
- Name it: `[YourName] - P1 Incident Response Dashboard`
- Click Edit to begin adding panels

---

## Step 4: Add Section 1 — Incident Header Row

The top row should give a 30-second briefing on overall system health.

### Panel 1: Overall Error Rate (Single Value)

- Click Add Panel > New > Single Value
- Use this SPL query:

```spl
index=lab sourcetype=app_logs status=error
| eval total=1
| appendcols [search index=lab sourcetype=app_logs | stats count as total_requests]
| stats count as error_count, values(total_requests) as total_requests
| eval error_rate=round((error_count/total_requests)*100,2)
| table error_rate
```

- Set conditional formatting:
  - 0-1%: Green background
  - 1-5%: Yellow background
  - Greater than 5%: Red background
- Title: `Overall Error Rate %`
- Time range: Last 15 minutes

### Panel 2: Request Throughput (Single Value)

```spl
index=lab sourcetype=app_logs
| stats count as request_count
| eval rps=round(request_count/900,2)
| table rps
```

Title: `Requests/sec` — Conditional formatting: less than 100 rps = Yellow

### Panel 3: P99 Latency (Single Value)

```spl
index=lab sourcetype=app_logs
| stats perc99(response_time_ms) as p99_latency
| table p99_latency
```

Title: `P99 Latency (ms)` — Conditional formatting: greater than 500ms = Yellow, greater than 1000ms = Red

### Panel 4: Host CPU Status (Table or Single Value)

```spl
index=lab sourcetype=os_metrics metric_name=cpu.usage
| stats avg(value) as avg_cpu by host
| sort -avg_cpu
```

Title: `Infrastructure Health — CPU by Host`

---

## Step 5: Add Section 2 — Application Performance Row

The second row provides deep application visibility.

### Panel 5: Latency Percentiles Over Time (Line Chart)

```spl
index=lab sourcetype=app_logs
| timechart span=1m perc50(response_time_ms) as p50, perc95(response_time_ms) as p95, perc99(response_time_ms) as p99 by service
```

Display: Line chart — Title: `Request Latency by Service (P50/P95/P99)`

### Panel 6: Top Slow Endpoints (Table)

```spl
index=lab sourcetype=app_logs
| stats avg(response_time_ms) as avg_latency by endpoint
| sort -avg_latency
| head 10
```

Title: `Slowest Endpoints`

---

## Step 6: Add Section 3 — Infrastructure Metrics Row

### Panel 8: CPU Usage by Host (Area Chart)

```spl
index=lab sourcetype=os_metrics metric_name=cpu.usage
| timechart span=1m avg(value) by host
```

Display: Stacked area — Title: `CPU Usage by Host`

### Panel 9: Memory Usage (Line Chart)

```spl
index=lab sourcetype=os_metrics metric_name=mem.used
| timechart span=1m avg(value) by host
```

Display: Lines — Title: `Memory Usage`

### Panel 10: Network I/O (Line Chart)

```spl
index=lab sourcetype=os_metrics (metric_name=net.bytes_sent OR metric_name=net.bytes_rcvd)
| timechart span=1m avg(value) by metric_name
```

Display: Lines — Title: `Network I/O (bytes/sec)`

---

## Step 7: Add Section 4 — Live Log Stream

### Panel 11: Error Log Volume by Service (Bar Chart)

```spl
index=lab sourcetype=app_logs status=error
| timechart span=1m count by service
```

Display: Column/bar chart — Title: `Error Log Volume by Service`

---

# Part 3: Time Synchronization and Comparison Views (20 minutes)

## Step 8: Master the Global Time Picker

One of the most powerful incident response features in Splunk dashboards is the ability to lock all panels to a specific incident window simultaneously.

### Setting a Custom Incident Time Window

- In the top-right of your dashboard, click the time picker (currently shows `Last 24 hours` or similar)
- Click Custom Time Range
- Set the start time to 5 minutes before your incident simulation starts
- Set the end time to `now` or a fixed window
- Click Apply — all panels on the dashboard now share this time range

**Why Time Sync Matters:** Without time sync, different panels may show different time ranges, making correlation impossible. During an incident, the first thing to do is set your dashboard to the incident window. Example: "Incident started at 14:30 based on PagerDuty alert. Set dashboard to 14:25-15:00 to see pre/post patterns."

### Using Event Annotations to Mark Incident Start

In Dashboard Studio you can add annotations to timeseries panels:

- Edit your timeseries panel (Panel 5 or Panel 8)
- Add an overlay query that returns the deploy or incident event timestamp:

```spl
index=lab sourcetype=deploy_events
| table _time, event_type, service
```

- Use this as an overlay on your main chart to place a vertical marker at the deploy time
- This helps you visually correlate exactly when things changed

---

## Step 9: Comparison Views — Before vs. After

Comparison views are essential for understanding change — the most common cause of incidents.

### Before vs. After Deploy Comparison

- Identify a deploy time (we will simulate one in Part 4)
- Use the dashboard time picker to set: Start = 30 min before deploy, End = 30 min after deploy
- Hover over the deploy time on your charts to see the exact moment metrics changed — this is your correlation point

You can also run a direct SPL comparison:

```spl
index=lab sourcetype=app_logs
| eval period=if(_time < relative_time(now(),"-30m"), "before_deploy", "after_deploy")
| stats avg(response_time_ms) as avg_latency, count as requests by period, service
```

---

# Part 4: Correlating Application with Infrastructure and Logs (20 minutes)

## Step 10: Build a Correlation Workflow

Correlation is the skill that separates expert incident responders from beginners. Follow this proven workflow:

| Step | Action | Dashboard Element |
|---|---|---|
| 1. Spot the symptom | Error rate spikes on a service | Panel 6: Error Rate by Service |
| 2. Identify the scope | Which hosts are affected? | Panel 8: CPU Usage by Host |
| 3. Check application traces | What is the slow operation? | Panel 7: Top Slow Endpoints |
| 4. Find the evidence | What do the logs say? | Panel 11: Error Log Stream |
| 5. Confirm the cause | Did a deploy coincide? | Event overlay on Panel 5 |

---

## Step 11: Add a Correlation View — App Latency + CPU Side by Side

Create a combined chart that shows application latency next to CPU usage for the same service and host:

- Add a new timeseries panel
- Use this SPL to plot both on the same chart:

```spl
index=lab (sourcetype=app_logs service=api-service) OR (sourcetype=os_metrics host=api-service-host metric_name=cpu.usage)
| eval latency=if(sourcetype=="app_logs", response_time_ms, null())
| eval cpu=if(sourcetype=="os_metrics", value, null())
| timechart span=1m avg(latency) as avg_latency, avg(cpu) as avg_cpu
```

- In Chart Format, enable dual Y-axis so latency and CPU are on separate scales
- Title: `App Latency vs CPU — api-service`

**What Good Correlation Looks Like:**
- Latency spikes and CPU spikes at the same time — likely a resource exhaustion issue
- Latency spikes but CPU is flat — likely an upstream dependency issue (database, external API)
- Latency is flat but error rate spikes — likely a logic error or bad deploy, not a resource issue

---

## Step 12: Add a Log-App Metrics Correlation Panel

This panel lets you compare application error rate and log error volume on the same chart:

```spl
index=lab (sourcetype=app_logs) 
| timechart span=1m count(eval(status="error")) as apm_errors, count(eval(log_level="ERROR")) as log_errors
```

Overlay both metrics on the same graph — you should see log errors closely following application errors.

Title: `App Errors vs Log Errors (should correlate)`

If application errors and log errors spike at different times, investigate: are all services logging properly? Is log collection keeping up with volume?

---

# Part 5: Hands-On Incident Simulation (30 minutes)

## Step 13: Simulate a Production Incident

Now you will use your dashboard to investigate a real simulated incident. This exercise mirrors what happens during an actual P1.

### Scenario: The Checkout Service is Failing

Your monitoring alerts at 14:30. Users are reporting that checkout is broken. Error rates are elevated. You have your dashboard open.

### Phase 1: Inject the Failure (The Incident)

```bash
# Scale PostgreSQL to 0 replicas (simulate database outage)
kubectl scale deployment postgres -n service-map-lab --replicas=0

# Verify database pod is gone
kubectl get pods -n service-map-lab -l app=postgres
```

### Phase 2: Investigate Using Your Dashboard

Follow this investigation protocol using only your dashboard:

- Set the dashboard time range to start 2 minutes before the incident injection
- Look at Panel 1 (Overall Error Rate) — has it changed?
- Look at Panel 6 (Error Rate by Service) — which service is affected?
- Cross-reference Panel 8 (CPU by Host) — is there a correlated CPU spike?
- Note the exact timestamp when things changed — this is your incident start time

### Investigation Worksheet

| Question | Where to Look | Your Finding |
|---|---|---|
| When did the incident start? | Panel 6 - first error spike | |
| Which service is affected? | Panel 6 - colored by service | |
| Is it infra or app issue? | Panel 8 - CPU correlation | |
| What is the error message? | Panel 11 - log stream | |
| Which endpoint is slowest? | Panel 7 - top list | |
| Did a deploy precede this? | Event overlay on Panel 5 | |

### Phase 3: Resolve and Confirm Recovery

Watch your dashboard — within 2-3 minutes, all metrics should return to baseline. This is your "recovery confirmation" using the dashboard.

```bash
# Scale PostgreSQL back to 1 replica (resolve the outage)
kubectl scale deployment postgres -n service-map-lab --replicas=1

# Verify database pod is back
kubectl get pods -n service-map-lab -l app=postgres
```

---

# Part 6: Dashboard Best Practices and Sharing (10 minutes)

## Step 14: Save and Share Your Dashboard

### Add Input Controls (Tokens / Filters)

Tokens make your dashboard reusable across environments and services. In Splunk Classic Dashboards or Dashboard Studio:

- Edit your dashboard XML or use the UI to add input dropdowns at the top
- Add the following inputs:

| Input Name | Field | Default Value |
|---|---|---|
| `$env$` | env | lab |
| `$service$` | service | * |
| `$host$` | host | * |

- Update each panel query to use `$env$` instead of hardcoded `lab`
- Example: Change `index=lab` to `index=$env$` in all queries

**Sharing the Dashboard**

- Click the share icon on your dashboard
- Choose Permissions: App > Read for all users who need access
- Copy the direct URL and share it with your team — everyone opening this URL during an incident sees the same panels in sync

---

# Key Takeaways

| Concept | What You Learned | Why It Matters |
|---|---|---|
| P1 Dashboard Structure | Combine System + App + Logs in one unified view with a logical section hierarchy | Reduces cognitive overhead during high-stress incidents |
| Time Synchronization | Lock all panels to the incident window; mark start/end with events | Ensures all signals are compared at the same point in time |
| Comparison Views | Last 1h vs. previous; before/after deploy markers | The most common root cause is recent change — comparison makes it visible |
| App + Infra Correlation | Plot app latency alongside CPU/memory on shared axes | Determines if incident is application logic or resource exhaustion |
| Log-App Pivot | Correlate error log volume with application error rate timeseries | Confirms whether the application is logging the errors the APM is seeing |
| Input Tokens | Parameterize dashboards by env, service, host | One dashboard serves all environments and services — no duplication |

---

## Troubleshooting

### Panels Showing "No Results"

- Verify the Universal Forwarder is running: `sudo systemctl status SplunkForwarder`
- Check your index name matches what is in your queries — run `| eventcount summarize=false index=*` to list available indexes
- Ensure the time range on the panel is wide enough to capture data
- Check the sourcetype is correct — run `index=lab | stats count by sourcetype` to see what is available

### Time Sync Not Working Across Panels

- Ensure all panels use the global time token `$earliest$` and `$latest$` instead of a fixed time range
- In panel edit mode, check that "Use time range from search bar" or global time picker is enabled
- After changing the global time picker, click Apply and wait a moment for all panels to refresh

### Log Stream Panel is Empty

- Run a manual search: `index=lab sourcetype=app_logs | head 20` to verify logs are coming in
- Check the forwarder inputs.conf to confirm the log path is correct
- Verify `index` and `sourcetype` values match exactly what is configured in your forwarder
- Check for time parsing issues: `index=lab | eval age=now()-_time | stats max(age) as oldest_event_sec` — if age is very large, check the time zone configuration on your forwarder

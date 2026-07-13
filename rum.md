# Splunk Observability — RUM & Synthetic Testing Lab (Apache Tomcat / Rocky Linux, Agent-Based)

> **Prerequisites:** Complete the *Apache Tomcat — Rocky Linux* APM lab first. Tomcat is running on port `8080`, the Splunk Java agent (`splunk-otel-javaagent.jar`) is attached via `JAVA_OPTS`, `OTEL_SERVICE_NAME=tomcat-lab` is set, and the Splunk OTel Collector is running. Node.js and npm are available on the host. You have a Splunk Observability Cloud **RUM access token** and know your **realm**.

**Estimated time:** 60–75 minutes

---

## Why This Lab Is Different From a Static Site

In the earlier static-Apache version of this lab, RUM and Synthetics ran with no real backend to correlate against. Here, Tomcat is already emitting real APM traces as `tomcat-lab`. That means once RUM and Synthetics are wired up, you get the **full three-way correlation**: a synthetic run or a real browser session can open the exact backend trace that served it.

---

## Lab Overview

| Module | What You'll Do |
|--------|---------------|
| **Module 1** | Set up the npm build project for the RUM agent |
| **Module 2** | Instrument the app and bundle the agent with esbuild |
| **Module 3** | Deploy the bundle into Tomcat's webapps ROOT |
| **Module 4** | Enable RUM ↔ APM trace linking (`Server-Timing` header) |
| **Module 5** | Generate traffic and verify RUM data |
| **Module 6** | Create Synthetic Browser Tests |
| **Module 7** | Create Synthetic API Tests (Uptime Checks) |
| **Module 8** | Build a Synthetic + RUM + APM Dashboard |
| **Module 9** | Simulate errors and observe full-stack correlation |
| **Module 10** | Rebuild workflow after config changes |
| **Module 11** | Cleanup |

---

## Prerequisites Check

```bash
node -v
npm -v
sudo systemctl status tomcat
curl -I http://localhost:8080/
```

If Node isn't installed:

```bash
sudo dnf install -y nodejs
```

Generate a RUM access token in Splunk Observability Cloud (**Settings → Access Tokens → New Token → RUM Token**) and note your realm before continuing.

> **Note:** RUM tokens are different from the ingest token used by the Java agent and the Collector. Keep both handy.

---

## Module 1 — Set Up the npm Build Project

The npm-based agent needs to be bundled — it isn't loaded as a loose CDN script tag, so a small build project is required first.

```bash
sudo mkdir -p /opt/rum-build
cd /opt/rum-build
sudo npm init -y
sudo npm install @splunk/otel-web
sudo npm install --save-dev esbuild
```

### Validate

```bash
ls /opt/rum-build/node_modules/@splunk/otel-web
```

**Expected:** the package directory is present with no errors.

---

## Module 2 — Instrument and Bundle the App

### 2.1 Create the Instrumentation File

Use the **same application name as the backend service** (`tomcat-lab`) so RUM and APM data line up cleanly in dashboards and correlation views.

```bash
sudo tee /opt/rum-build/splunk-instrumentation.js > /dev/null <<'EOF'
import { SplunkRum } from '@splunk/otel-web';

SplunkRum.init({
  realm: '<your-realm>',
  rumAccessToken: '<your-rum-token>',
  applicationName: 'tomcat-lab',
  deploymentEnvironment: 'lab',
});
EOF
```

Replace `<your-realm>` and `<your-rum-token>` with your actual values.

### 2.2 Bundle It

```bash
cd /opt/rum-build
sudo npx esbuild splunk-instrumentation.js --bundle --outfile=/opt/rum-build/splunk-rum-bundle.js
```

We bundle to a staging path first because, unlike the static-Apache lab, Tomcat's docroot isn't `/var/www/html` — it needs to be located.

---

## Module 3 — Deploy the Bundle Into Tomcat's Webapps ROOT

### 3.1 Locate Tomcat's Real Docroot

Tomcat's package layout varies by install method. Find the actual `ROOT` webapp directory rather than assuming a path:

```bash
find / -iname "ROOT" -path "*webapps*" 2>/dev/null
```

**Expected:** something like `/usr/share/tomcat/webapps/ROOT` or `/var/lib/tomcat/webapps/ROOT`. Export it for the rest of this lab:

```bash
export TOMCAT_ROOT=$(find / -iname "ROOT" -path "*webapps*" 2>/dev/null | head -1)
echo "$TOMCAT_ROOT"
```

### 3.2 Copy the Bundle Into Place

```bash
sudo cp /opt/rum-build/splunk-rum-bundle.js "$TOMCAT_ROOT/"
```

### 3.3 Validate

```bash
ls -lh "$TOMCAT_ROOT/splunk-rum-bundle.js"
curl -I http://localhost:8080/splunk-rum-bundle.js
```

**Expected:** the file exists and Tomcat serves it with HTTP `200`.

### 3.4 Reference the Bundle From the Page

Edit the page Tomcat actually serves (commonly `index.jsp` or `index.html` inside `$TOMCAT_ROOT`):

```bash
sudo vi "$TOMCAT_ROOT/index.jsp"
```

Add this as the **first script** inside `<head>`, before any other scripts:

```html
<head>
  <script src="/splunk-rum-bundle.js"></script>
  <!-- rest of existing head content -->
</head>
```

No Tomcat restart is needed — static files under `webapps/ROOT` serve immediately.

---

## Module 4 — Enable RUM ↔ APM Trace Linking

By default, RUM captures frontend timing and the Java agent captures backend traces — but nothing links a specific page's network request to the specific backend span that handled it. The Splunk distributions enable this via a `Server-Timing` response header from the backend.

### 4.1 Add the Trace Response Header Env Var

```bash
sudo sed -i '/^JAVA_OPTS=/ s/^/#/' /etc/tomcat/tomcat.conf

sudo tee -a /etc/tomcat/tomcat.conf > /dev/null <<'EOF'
JAVA_OPTS="-Djavax.sql.DataSource.Factory=org.apache.commons.dbcp.BasicDataSourceFactory -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=9012 -Dcom.sun.management.jmxremote.rmi.port=9012 -Dcom.sun.management.jmxremote.local.only=false -Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.ssl=false -Djava.rmi.server.hostname=localhost -javaagent:/opt/splunk-otel-javaagent/splunk-otel-javaagent.jar"
OTEL_SERVICE_NAME=tomcat-lab
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318
OTEL_RESOURCE_ATTRIBUTES=deployment.environment=lab
SPLUNK_TRACE_RESPONSE_HEADER_ENABLED=true
EOF

sudo systemctl restart tomcat
```

### 4.2 Validate

```bash
curl -I http://localhost:8080/ | grep -i server-timing
```

**Expected:** a `Server-Timing: traceparent;desc="00-<traceId>-<spanId>-01"` header is present. This is what lets a RUM session's XHR calls and a Synthetic Browser Test's requests open the matching APM trace directly.

---

## Module 5 — Generate Traffic and Verify RUM Data

### 5.1 Open the App in a Real Browser

RUM needs a real JS engine — `curl` won't generate session data.

```
http://<host>:8080/
```

Click around the page a few times to generate page-load and interaction spans.

### 5.2 Verify in the Splunk UI

1. Go to **Digital Experience → Real User Monitoring → Overview**
2. Filter **Source: Browser**
3. Confirm `tomcat-lab` appears with recent sessions
4. Open a session and confirm you see page load time, interactions, any network requests, and any JS errors
5. On a network request, look for a **View trace in APM** link — this confirms Module 4's header linking worked

---

## Module 6 — Synthetic Browser Tests

### 6.1 Create a Browser Test via UI

1. Navigate to **Synthetics → Create Test → Browser Test**
2. Configure:

| Field | Value |
|-------|-------|
| **Test Name** | `Tomcat Lab App — Homepage Journey` |
| **URL** | `http://<host>:8080/` *(use a publicly reachable URL, or a tunnel such as ngrok if the host is private)* |
| **Locations** | Pick 2–3 locations (e.g. `us-east-1`, `eu-west-1`) |
| **Frequency** | Every 5 minutes |

3. Add steps appropriate to your page:

```
Step 1 — Navigate
  Action: go_to
  URL: http://<host>:8080/

Step 2 — Wait for page
  Action: wait_for_element
  Selector: body

Step 3 — Assert RUM bundle loaded
  Action: assert_element
  Selector: script[src="/splunk-rum-bundle.js"]
  Condition: is_present
```

4. Click **Save & Run**.

### 6.2 Create a Browser Test via API (optional)

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/browser" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Tomcat Lab App — Homepage Journey",
    "frequency": 5,
    "locations": ["aws-us-east-1", "aws-eu-west-1"],
    "active": true,
    "url": "http://<host>:8080/",
    "steps": [
      { "name": "Go to homepage", "type": "go_to_url", "url": "http://<host>:8080/" },
      { "name": "Assert RUM bundle present", "type": "assert_element_present", "selector": "script[src=\"/splunk-rum-bundle.js\"]" }
    ]
  }'
```

### 6.3 View Results

1. **Synthetics → Tests** → click your test name
2. Check the **Waterfall chart** for the request to `/`
3. Because Module 4 added the `Server-Timing` header, this run's requests should carry an **APM link** — click through to confirm you land on a `tomcat-lab` trace

---

## Module 7 — Synthetic API Tests (Uptime Checks)

### 7.1 Homepage Availability Check

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Tomcat Host — Homepage Health Check",
    "frequency": 1,
    "locations": ["aws-us-east-1"],
    "active": true,
    "requests": [
      {
        "name": "GET /",
        "request": {
          "url": "http://<host>:8080/",
          "method": "GET"
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" },
          { "type": "RESPONSE_TIME", "comparator": "less_than", "expected": "2000" }
        ]
      }
    ]
  }'
```

### 7.2 RUM Bundle Availability Check

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Tomcat Host — RUM Bundle Availability",
    "frequency": 5,
    "locations": ["aws-us-east-1", "aws-ap-southeast-1"],
    "active": true,
    "requests": [
      {
        "name": "GET /splunk-rum-bundle.js",
        "request": {
          "url": "http://<host>:8080/splunk-rum-bundle.js",
          "method": "GET"
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" },
          { "type": "HEADER", "comparator": "contains", "expected": "javascript" }
        ]
      }
    ]
  }'
```

### 7.3 Server-Timing Header Check

Confirms trace linking stays configured, not just that the page loads:

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Tomcat Host — Trace Header Present",
    "frequency": 10,
    "locations": ["aws-us-east-1"],
    "active": true,
    "requests": [
      {
        "name": "GET / (check headers)",
        "request": {
          "url": "http://<host>:8080/",
          "method": "GET"
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" },
          { "type": "HEADER", "comparator": "contains", "expected": "traceparent" }
        ]
      }
    ]
  }'
```

### 7.4 Multi-Step API Test (Chained Requests)

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Tomcat App — Homepage then Asset Chain",
    "frequency": 10,
    "locations": ["aws-us-east-1"],
    "active": true,
    "requests": [
      {
        "name": "Step 1 — Load homepage",
        "request": {
          "url": "http://<host>:8080/",
          "method": "GET"
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" }
        ],
        "extractors": [
          { "type": "HEADER", "source": "HEADERS", "expression": "ETag", "variable": "PAGE_ETAG" }
        ]
      },
      {
        "name": "Step 2 — Load RUM bundle",
        "request": {
          "url": "http://<host>:8080/splunk-rum-bundle.js",
          "method": "GET"
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" }
        ]
      }
    ]
  }'
```

---

## Module 8 — Build a Synthetic + RUM + APM Dashboard

### 8.1 Create a Dashboard

1. Navigate to **Dashboards → Create Dashboard**
2. Name it: `Tomcat Lab App — Synthetic, RUM & APM Overview`

### 8.2 Add These Charts

#### Chart 1 — Synthetic Test Response Time

```
data('synthetics.run.duration', filter=filter('test_name', 'Tomcat Host — Homepage Health Check'))
.mean()
.publish(label='Avg Response Time (ms)')
```

#### Chart 2 — RUM Page Load Time (P75)

```
data('rum.page_load.time.ns', filter=filter('app', 'tomcat-lab'))
.percentile(pct=75)
.scale(1e-6)
.publish(label='Page Load P75 (ms)')
```

#### Chart 3 — RUM JS Error Rate

```
data('rum.client_error.count', filter=filter('app', 'tomcat-lab'))
.sum(over='1m')
.publish(label='JS Errors / min')
```

#### Chart 4 — JVM Heap Usage (from the APM lab's JMX receiver)

```
data('jvm.memory.heap.used', filter=filter('service.name', 'tomcat-lab'))
.mean()
.publish(label='JVM Heap Used')
```

#### Chart 5 — Synthetic vs RUM vs Backend Response Time

```
data('synthetics.run.duration', filter=filter('test_name', 'Tomcat Host — Homepage Health Check')).mean().publish(label='Synthetic (External)')
data('rum.document.time_to_first_byte.ns', filter=filter('app', 'tomcat-lab')).percentile(pct=50).scale(1e-6).publish(label='RUM TTFB P50 (ms)')
```

### 8.3 Add Detectors (Alerts)

#### Synthetic Alert — Test Failure

```
detect(
  when(
    data('synthetics.run.count', filter=filter('success', 'false'))
      .sum(over='5m') > 2
  )
).publish('Synthetic Test Failing — tomcat-lab')
```

#### RUM Alert — High Error Rate

```
detect(
  when(
    data('rum.client_error.count', filter=filter('app', 'tomcat-lab'))
      .sum(over='5m') > 10
  )
).publish('High JS Error Rate — tomcat-lab')
```

#### JVM Alert — Heap Pressure (ties RUM/Synthetic symptoms back to backend cause)

```
detect(
  when(
    data('jvm.memory.heap.used', filter=filter('service.name', 'tomcat-lab'))
      .mean(over='5m') > 800000000
  )
).publish('Tomcat Heap Usage High — tomcat-lab')
```

---

## Module 9 — Simulate Errors & Observe Full-Stack Correlation

### 9.1 Stop Tomcat

```bash
sudo systemctl stop tomcat
```

Wait 2–3 minutes, then observe:
- Synthetic Browser Test and API Test → both **fail**
- RUM → sessions stop arriving, since the page can't load
- APM → no new traces for `tomcat-lab`

Restore the service:

```bash
sudo systemctl start tomcat
curl http://localhost:8080/ > /dev/null
```

### 9.2 Inject JavaScript Errors

Open your browser console at `http://<host>:8080/` and run:

```javascript
Promise.reject(new Error("Simulated checkout failure"));
undefinedFunction();
```

Check **RUM → Errors** for these, tagged to `tomcat-lab`.

### 9.3 Correlate Synthetic → APM Trace

Because Module 4 enabled the `Server-Timing` header:

1. Go to **Synthetics → your browser test → a recent run**
2. Click **View APM trace** on the homepage request
3. This opens the exact backend trace in APM, letting you see whether the slowness (or failure) originated in the JVM, a downstream call, or elsewhere

### 9.4 Correlate RUM → APM Trace

1. Go to **RUM → Sessions**
2. Click a session, then any XHR/document request
3. Click **View trace in APM** to open the specific backend trace for that request
4. Cross-check against the JVM heap chart from Module 8 to see if backend pressure explains what the user experienced

---

## Module 10 — Rebuild Workflow After Config Changes

Any time you edit `splunk-instrumentation.js` (e.g. `globalAttributes`, sampling, `deploymentEnvironment`), re-bundle and redeploy:

```bash
cd /opt/rum-build
sudo npx esbuild splunk-instrumentation.js --bundle --outfile=/opt/rum-build/splunk-rum-bundle.js
sudo cp /opt/rum-build/splunk-rum-bundle.js "$TOMCAT_ROOT/"
curl -I http://localhost:8080/splunk-rum-bundle.js
```

No Tomcat restart is required for the RUM bundle. A Tomcat restart **is** required if you change anything in `/etc/tomcat/tomcat.conf` (Java agent flags, `OTEL_*` env vars, the `Server-Timing` flag).

---

## Module 11 — Cleanup

```bash
# Remove the RUM bundle from Tomcat's docroot
sudo rm -f "$TOMCAT_ROOT/splunk-rum-bundle.js"

# Revert the <script> tag added in Module 3.4
sudo vi "$TOMCAT_ROOT/index.jsp"

# Remove the build project
sudo rm -rf /opt/rum-build

# Optionally remove all synthetic tests via API
curl -X GET "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" | jq '.tests[].id'

curl -X DELETE "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/<TEST_ID>" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>"
```

---

## Summary

| Capability | What Was Configured |
|-----------|---------------------|
| **RUM Agent (npm/bundled)** | `@splunk/otel-web` built with esbuild, deployed into Tomcat's `webapps/ROOT` |
| **RUM ↔ APM Linking** | `SPLUNK_TRACE_RESPONSE_HEADER_ENABLED=true` adds a `Server-Timing` header so frontend requests link to backend spans |
| **RUM Metrics** | Page load, TTFB, JS errors, Web Vitals |
| **Synthetic Browser Test** | Homepage journey with content and asset assertions, APM-linked via Server-Timing |
| **Synthetic API Tests** | Homepage health check, RUM bundle availability, trace-header check, chained request example |
| **Dashboards** | Combined Synthetic + RUM + JVM/APM view in one pane |
| **Detectors** | Alerts on synthetic failure, high JS error rate, and JVM heap pressure |
| **Full-Stack Correlation** | Synthetic run → APM trace, and RUM session → APM trace, both via the same `tomcat-lab` service |
| **Rebuild Workflow** | esbuild re-bundle + redeploy required after any RUM config change; Tomcat restart required for backend/env changes |

---

## Reference Links

- [Splunk RUM Browser Instrumentation](https://docs.splunk.com/observability/en/gdi/get-data-in/rum/browser/install-rum-browser.html)
- [Splunk Synthetics Test Types](https://docs.splunk.com/observability/en/synthetics/test-config/test-config.html)
- [Synthetics API Reference](https://dev.splunk.com/observability/reference/api/synthetics/latest)
- [RUM to APM Correlation](https://docs.splunk.com/observability/en/rum/rum-apm-connection.html)
- [SignalFlow Reference](https://dev.splunk.com/observability/docs/signalflow/)

# Splunk Observability — RUM & Synthetic Testing Lab (Apache / Rocky Linux, Agent-Based)

> **Prerequisites:** Apache is installed and serving `/var/www/html/index.html` (Exercise 1 of the Apache lab). Node.js and npm are available on the host. You have a Splunk Observability Cloud **RUM access token** and know your **realm** (e.g. `us0`, `us1`, `eu0`).

**Estimated time:** 60–75 minutes

---

## Lab Overview

| Module | What You'll Do |
|--------|---------------|
| **Module 1** | Set up the npm build project for the RUM agent |
| **Module 2** | Instrument the Apache app and bundle the agent with esbuild |
| **Module 3** | Generate traffic and verify RUM data in Splunk |
| **Module 4** | Create Synthetic Browser Tests |
| **Module 5** | Create Synthetic API Tests (Uptime Checks) |
| **Module 6** | Build a Synthetic + RUM Dashboard |
| **Module 7** | Simulate errors and observe correlation |
| **Module 8** | Rebuild workflow after config changes |
| **Module 9** | Cleanup |

---

## Prerequisites Check

```bash
node -v
npm -v
```

If Node isn't installed:

```bash
sudo dnf install -y nodejs
```

Generate a RUM access token in Splunk Observability Cloud (**Settings → Access Tokens → New Token → RUM Token**) and note your realm before continuing.

> **Note:** RUM tokens are different from the ingest token used for APM. Keep both handy if you completed a prior APM lab.

---

## Module 1 — Set Up the npm Build Project

The npm-based agent needs to be bundled — it isn't loaded as a loose CDN script tag, so a small build project is required first.

### 1.1 Create the Build Folder

```bash
sudo mkdir -p /opt/rum-build
cd /opt/rum-build
sudo npm init -y
sudo npm install @splunk/otel-web
sudo npm install --save-dev esbuild
```

### 1.2 Verify the Install

```bash
ls /opt/rum-build/node_modules/@splunk/otel-web
```

**Expected:** the package directory is present with no errors.

---

## Module 2 — Instrument and Bundle the App

### 2.1 Create the Instrumentation File

```bash
sudo tee /opt/rum-build/splunk-instrumentation.js > /dev/null <<'EOF'
import { SplunkRum } from '@splunk/otel-web';

SplunkRum.init({
  realm: '<your-realm>',
  rumAccessToken: '<your-rum-token>',
  applicationName: 'apache-lab-app',
  deploymentEnvironment: 'lab',
});
EOF
```

Replace `<your-realm>` and `<your-rum-token>` with your actual values.

### 2.2 Bundle It Into Apache's Docroot

```bash
cd /opt/rum-build
sudo npx esbuild splunk-instrumentation.js --bundle --outfile=/var/www/html/splunk-rum-bundle.js
```

### 2.3 Validate the Bundle

```bash
ls -lh /var/www/html/splunk-rum-bundle.js
curl -I http://localhost/splunk-rum-bundle.js
```

**Expected:** the file exists and Apache serves it with HTTP `200`.

### 2.4 Reference the Bundle From the Page

```bash
sudo vi /var/www/html/index.html
```

Add this as the **first script** inside `<head>`, before any other scripts:

```html
<head>
  <script src="/splunk-rum-bundle.js"></script>
  <!-- rest of existing head content -->
</head>
```

No Apache restart is needed — static files serve immediately.

---

## Module 3 — Generate Traffic and Verify RUM Data

### 3.1 Open the App in a Real Browser

RUM needs a real JS engine — `curl` won't generate session data.

```
http://<host>/
```

Click around the page a few times (links, buttons, forms) to generate page-load and interaction spans.

### 3.2 Verify in the Splunk UI

1. Go to **Digital Experience → Real User Monitoring → Overview**
2. Filter **Source: Browser**
3. Confirm `apache-lab-app` appears with recent sessions
4. Drill into a session and confirm you see:
   - Page load time
   - User interactions
   - Any network/XHR requests fired by the page
   - Any JS errors

---

## Module 4 — Synthetic Browser Tests

Synthetic Browser Tests replay a real user journey against your Apache host using a headless Chrome browser from Splunk-managed locations — independent of any real visitor.

### 4.1 Create a Browser Test via UI

1. Navigate to **Synthetics → Create Test → Browser Test**
2. Configure:

| Field | Value |
|-------|-------|
| **Test Name** | `Apache Lab App — Homepage Journey` |
| **URL** | `http://<host>/` *(use a publicly reachable URL, or a tunnel such as ngrok if the host is private)* |
| **Locations** | Pick 2–3 locations (e.g. `us-east-1`, `eu-west-1`) |
| **Frequency** | Every 5 minutes |

3. In the **Steps** editor, add steps appropriate to your page, for example:

```
Step 1 — Navigate
  Action: go_to
  URL: http://<host>/

Step 2 — Wait for page
  Action: wait_for_element
  Selector: body

Step 3 — Assert content loaded
  Action: assert_text
  Selector: h1
  Expected: (page heading text)

Step 4 — Assert RUM bundle loaded
  Action: assert_element
  Selector: script[src="/splunk-rum-bundle.js"]
  Condition: is_present
```

4. Click **Save & Run** to execute immediately.

### 4.2 Create a Browser Test via API (optional)

Replace `<YOUR_TOKEN>`, `<YOUR_REALM>`, and `<host>`:

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/browser" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Apache Lab App — Homepage Journey",
    "frequency": 5,
    "locations": ["aws-us-east-1", "aws-eu-west-1"],
    "active": true,
    "url": "http://<host>/",
    "steps": [
      { "name": "Go to homepage", "type": "go_to_url", "url": "http://<host>/" },
      { "name": "Assert heading visible", "type": "assert_element_present", "selector": "h1" }
    ]
  }'
```

### 4.3 View Browser Test Results

1. **Synthetics → Tests** → click your test name
2. Explore:
   - **Filmstrip** — screenshot-by-screenshot playback
   - **Waterfall chart** — every network request and its timing, including `splunk-rum-bundle.js`
   - **Web Vitals** — LCP, FID, CLS scores
   - **Run history** — pass/fail over time per location

---

## Module 5 — Synthetic API Tests (Uptime Checks)

API tests hit HTTP endpoints directly, without a browser — ideal for basic availability checks on the Apache host.

### 5.1 Homepage Availability Check

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Apache Host — Homepage Health Check",
    "frequency": 1,
    "locations": ["aws-us-east-1"],
    "active": true,
    "requests": [
      {
        "name": "GET /",
        "request": {
          "url": "http://<host>/",
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

### 5.2 RUM Bundle Availability Check

Confirms the instrumentation bundle itself stays reachable — if this fails, RUM data silently stops flowing even though the site looks fine.

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Apache Host — RUM Bundle Availability",
    "frequency": 5,
    "locations": ["aws-us-east-1", "aws-ap-southeast-1"],
    "active": true,
    "requests": [
      {
        "name": "GET /splunk-rum-bundle.js",
        "request": {
          "url": "http://<host>/splunk-rum-bundle.js",
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

### 5.3 mod_status Health Check (optional)

If `mod_status` is enabled on the Apache host, monitor it directly:

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Apache Host — mod_status Check",
    "frequency": 5,
    "locations": ["aws-us-east-1"],
    "active": true,
    "requests": [
      {
        "name": "GET /server-status?auto",
        "request": {
          "url": "http://<host>/server-status?auto",
          "method": "GET"
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" },
          { "type": "BODY", "comparator": "contains", "expected": "Total Accesses" }
        ]
      }
    ]
  }'
```

### 5.4 Multi-Step API Test (Chained Requests)

If your Apache app fronts a small API (adjust paths to match your actual endpoints), chain requests and extract values between steps:

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Apache App — Homepage then Asset Chain",
    "frequency": 10,
    "locations": ["aws-us-east-1"],
    "active": true,
    "requests": [
      {
        "name": "Step 1 — Load homepage",
        "request": {
          "url": "http://<host>/",
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
          "url": "http://<host>/splunk-rum-bundle.js",
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

## Module 6 — Build a Synthetic + RUM Dashboard

### 6.1 Create a Dashboard in Splunk Observability

1. Navigate to **Dashboards → Create Dashboard**
2. Name it: `Apache Lab App — Synthetic & RUM Overview`

### 6.2 Add These Charts

#### Chart 1 — Synthetic Test Response Time

```
# SignalFlow
data('synthetics.run.duration', filter=filter('test_name', 'Apache Host — Homepage Health Check'))
.mean()
.publish(label='Avg Response Time (ms)')
```

```
# For pass/fail rate
data('synthetics.run.count', filter=filter('success', 'true'))
.sum()
.publish(label='Successful Runs')
```

#### Chart 2 — RUM Page Load Time (P75)

```
# SignalFlow
data('rum.page_load.time.ns', filter=filter('app', 'apache-lab-app'))
.percentile(pct=75)
.scale(1e-6)   # convert ns to ms
.publish(label='Page Load P75 (ms)')
```

#### Chart 3 — RUM JS Error Rate

```
data('rum.client_error.count', filter=filter('app', 'apache-lab-app'))
.sum(over='1m')
.publish(label='JS Errors / min')
```

#### Chart 4 — RUM Long Tasks (Web Vitals)

```
data('rum.long_task.count', filter=filter('app', 'apache-lab-app'))
.sum(over='5m')
.publish(label='Long Tasks (5m)')
```

#### Chart 5 — Synthetic vs RUM Response Time Comparison

Add both SignalFlow queries on the same chart:

```
data('synthetics.run.duration', filter=filter('test_name', 'Apache Host — Homepage Health Check')).mean().publish(label='Synthetic (External)')
data('rum.document.time_to_first_byte.ns', filter=filter('app', 'apache-lab-app')).percentile(pct=50).scale(1e-6).publish(label='RUM TTFB P50 (ms)')
```

### 6.3 Add Detectors (Alerts)

#### Synthetic Alert — Test Failure

1. **Alerts → Create Detector**
2. Use this SignalFlow:

```
detect(
  when(
    data('synthetics.run.count', filter=filter('success', 'false'))
      .sum(over='5m') > 2
  )
).publish('Synthetic Test Failing — apache-lab-app')
```

#### RUM Alert — High Error Rate

```
detect(
  when(
    data('rum.client_error.count', filter=filter('app', 'apache-lab-app'))
      .sum(over='5m') > 10
  )
).publish('High JS Error Rate — apache-lab-app')
```

#### RUM Alert — Bundle Not Loading (slow/no RUM data)

```
detect(
  when(
    data('rum.page_load.count', filter=filter('app', 'apache-lab-app'))
      .sum(over='15m') < 1
  )
).publish('No RUM Data Received — apache-lab-app')
```

---

## Module 7 — Simulate Errors & Observe Correlation

### 7.1 Inject a Slow / Unavailable Response

Stop Apache to simulate an outage:

```bash
sudo systemctl stop httpd
```

Wait 2–3 minutes, then observe:
- Synthetic Browser Test → starts **failing** on navigation
- Synthetic API Test (`GET /`) → status assertion **fails**, response time spikes or times out
- RUM → sessions stop arriving entirely, since the page itself can't load

Restore the service:

```bash
sudo systemctl start httpd
```

### 7.2 Inject JavaScript Errors

Open your browser console at `http://<host>/` and run:

```javascript
// Simulate an unhandled promise rejection
Promise.reject(new Error("Simulated form submission failure"));

// Simulate a runtime error
undefinedFunction();
```

Check **RUM → Errors** — you should see these errors with full stack traces, tagged to the `apache-lab-app` application.

### 7.3 Correlate Synthetic → RUM

Because both the Synthetic Browser Test and real users load the same `splunk-rum-bundle.js`, a failing deploy shows up in both:

1. Go to **Synthetics → your browser test → a recent failing run**
2. Compare the failure window against **RUM → Overview** for the same time range
3. A drop in RUM session volume alongside a synthetic failure is a strong signal the outage affected real users, not just the synthetic probe

### 7.4 Correlate RUM → Session Detail

1. Go to **RUM → Sessions**
2. Click on a session with errors
3. Inspect the timeline for the injected errors and confirm they're attributed to the correct page view and application name

---

## Module 8 — Rebuild Workflow After Config Changes

The npm-based approach bundles configuration into the JS file at build time — unlike a CDN script tag, which can be edited directly in the HTML. Any time you edit `splunk-instrumentation.js` (for example, to add `globalAttributes`, adjust sampling, or change `deploymentEnvironment`), re-run the bundle step:

```bash
cd /opt/rum-build
sudo npx esbuild splunk-instrumentation.js --bundle --outfile=/var/www/html/splunk-rum-bundle.js
```

Then re-validate:

```bash
curl -I http://localhost/splunk-rum-bundle.js
```

No Apache restart is required — the new bundle is picked up on the next page load.

---

## Module 9 — Cleanup

```bash
# Remove the RUM bundle from the docroot
sudo rm -f /var/www/html/splunk-rum-bundle.js

# Revert the <script> tag added in Module 2.4
sudo vi /var/www/html/index.html

# Remove the build project
sudo rm -rf /opt/rum-build

# Optionally remove all synthetic tests via API
curl -X GET "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" | jq '.tests[].id'

# Delete each test
curl -X DELETE "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/<TEST_ID>" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>"
```

---

## Summary

| Capability | What Was Configured |
|-----------|---------------------|
| **RUM Agent (npm/bundled)** | `@splunk/otel-web` built with esbuild into a static bundle served by Apache |
| **RUM Metrics** | Page load, TTFB, JS errors, Web Vitals, long tasks |
| **Synthetic Browser Test** | Homepage navigation journey with content and asset assertions |
| **Synthetic API Tests** | Homepage health check, RUM bundle availability, optional mod_status check, chained request example |
| **Dashboards** | Combined Synthetic + RUM view in one pane |
| **Detectors** | Alerts on test failure, high JS error rate, and missing RUM data |
| **Trace/Signal Correlation** | Synthetic failures cross-checked against RUM session volume and error data |
| **Rebuild Workflow** | esbuild re-bundle required after any instrumentation config change |

---

## Reference Links

- [Splunk RUM Browser Instrumentation](https://docs.splunk.com/observability/en/gdi/get-data-in/rum/browser/install-rum-browser.html)
- [Splunk Synthetics Test Types](https://docs.splunk.com/observability/en/synthetics/test-config/test-config.html)
- [Synthetics API Reference](https://dev.splunk.com/observability/reference/api/synthetics/latest)
- [RUM to APM Correlation](https://docs.splunk.com/observability/en/rum/rum-apm-connection.html)
- [SignalFlow Reference](https://dev.splunk.com/observability/docs/signalflow/)

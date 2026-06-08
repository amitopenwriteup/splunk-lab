# Splunk Observability — Synthetic Testing & RUM Lab

> **Prerequisites:** Complete the APM/Tracing lab (Splunk OTel Collector installed, `service-map-lab` namespace running, access token available).

---

## Lab Overview

| Module | What You'll Do |
|--------|---------------|
| **Module 1** | Deploy a sample frontend app with RUM instrumentation |
| **Module 2** | Configure Splunk RUM (Browser Agent) |
| **Module 3** | Create Synthetic Browser Tests |
| **Module 4** | Create Synthetic API Tests (Uptime Checks) |
| **Module 5** | Build a Synthetic + RUM Dashboard |
| **Module 6** | Simulate errors and observe correlation |

---

## Module 1 — Deploy the Frontend App

### 1.1 Create the Frontend Deployment

Create a simple e-commerce frontend that calls the existing `api-gateway` service.

**File: `frontend-deployment.yaml`**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: service-map-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            - name: html
              mountPath: /usr/share/nginx/html
      volumes:
        - name: html
          configMap:
            name: frontend-html
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: service-map-lab
spec:
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

Apply it:

```bash
kubectl apply -f frontend-deployment.yaml
```

---

### 1.2 Get Your RUM Access Token

In Splunk Observability Cloud:

1. Navigate to **Settings → Access Tokens**
2. Click **New Token** → select **RUM** as the token type
3. Copy the token — you'll use it in the next step

> **Note:** RUM tokens are different from the ingest token used for APM. Keep both handy.

---

## Module 2 — Configure Splunk RUM (Browser Agent)

### 2.1 Create the Frontend HTML with RUM Agent

Replace `<YOUR_RUM_TOKEN>` and `<YOUR_REALM>` (e.g. `us1`) before applying.

**File: `frontend-configmap.yaml`**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-html
  namespace: service-map-lab
data:
  index.html: |
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Shop — Service Map Lab</title>

      <!-- Splunk RUM Agent -->
      <script src="https://cdn.signalfx.com/o11y-gdi-rum/latest/splunk-otel-web.js"></script>
      <script>
        SplunkRum.init({
          realm: '<YOUR_REALM>',
          rumAccessToken: '<YOUR_RUM_TOKEN>',
          applicationName: 'shop-frontend',
          version: '1.0.0',
          environment: 'lab',
          deploymentEnvironment: 'lab'
        });
      </script>

      <style>
        body { font-family: sans-serif; max-width: 800px; margin: 40px auto; padding: 0 20px; }
        button { padding: 10px 20px; margin: 5px; cursor: pointer; }
        #result { margin-top: 20px; padding: 15px; background: #f0f0f0; border-radius: 4px; }
      </style>
    </head>
    <body>
      <h1>Shop Frontend</h1>
      <p>Use the buttons below to interact with the backend API.</p>

      <button onclick="createOrder()">Create Order</button>
      <button onclick="listOrders()">List Orders</button>
      <button onclick="checkInventory()">Check Inventory</button>
      <button onclick="triggerError()">Trigger Error (500)</button>

      <div id="result">Results will appear here...</div>

      <script>
        const API = 'http://localhost:8080';

        async function createOrder() {
          try {
            const res = await fetch(`${API}/api/orders`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ product_id: Math.ceil(Math.random()*10), quantity: 1 })
            });
            const data = await res.json();
            document.getElementById('result').textContent = JSON.stringify(data, null, 2);
          } catch (e) {
            document.getElementById('result').textContent = 'Error: ' + e.message;
          }
        }

        async function listOrders() {
          const res = await fetch(`${API}/api/orders`);
          const data = await res.json();
          document.getElementById('result').textContent = JSON.stringify(data, null, 2);
        }

        async function checkInventory() {
          const id = Math.ceil(Math.random()*10);
          const res = await fetch(`${API}/api/inventory/${id}`);
          const data = await res.json();
          document.getElementById('result').textContent = JSON.stringify(data, null, 2);
        }

        async function triggerError() {
          // Hit a non-existent endpoint to generate a 404/500
          const res = await fetch(`${API}/api/broken-endpoint`);
          document.getElementById('result').textContent = `Status: ${res.status}`;
        }
      </script>
    </body>
    </html>
```

Apply the ConfigMap:

```bash
kubectl apply -f frontend-configmap.yaml
kubectl rollout restart deployment frontend -n service-map-lab
```

### 2.2 Port-Forward the Frontend

```bash
kubectl port-forward -n service-map-lab svc/frontend 3000:80 &
kubectl port-forward -n service-map-lab svc/api-gateway 8080:80 &
```

Open your browser at **http://localhost:3000** and click through the buttons a few times to generate RUM data.

### 2.3 Verify RUM Data in Splunk

1. Go to **Splunk Observability → RUM**
2. Select application: `shop-frontend`
3. Confirm you see:
   - Page load times
   - User interactions (button clicks)
   - Network requests to `/api/orders`, `/api/inventory`
   - Any JS errors

---

## Module 3 — Synthetic Browser Tests

Synthetic Browser Tests replay a real user journey using a headless Chrome browser from Splunk-managed locations.

### 3.1 Create a Browser Test via UI

1. Navigate to **Synthetics → Create Test → Browser Test**
2. Configure:

| Field | Value |
|-------|-------|
| **Test Name** | `Shop Frontend — Order Journey` |
| **URL** | `http://localhost:3000` *(use your public URL or ngrok if needed)* |
| **Locations** | Pick 2–3 locations (e.g. `us-east-1`, `eu-west-1`) |
| **Frequency** | Every 5 minutes |

3. In the **Steps** editor, add the following steps:

```
Step 1 — Navigate
  Action: go_to
  URL: https://<your-app-url>

Step 2 — Wait for page
  Action: wait_for_element
  Selector: button  (first button on page)

Step 3 — Click "Create Order"
  Action: click
  Selector: button:nth-child(1)

Step 4 — Assert result
  Action: assert_text
  Selector: #result
  Expected: (does not contain "Error")

Step 5 — Click "List Orders"
  Action: click
  Selector: button:nth-child(2)

Step 6 — Assert status
  Action: assert_element
  Selector: #result
  Condition: is_visible
```

4. Click **Save & Run** to execute immediately.

### 3.2 Create a Browser Test via API (optional)

You can also create tests programmatically. Replace `<YOUR_TOKEN>` and `<YOUR_REALM>`:

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/browser" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Shop Frontend — Order Journey",
    "frequency": 5,
    "locations": ["aws-us-east-1", "aws-eu-west-1"],
    "active": true,
    "url": "https://<your-app-url>",
    "steps": [
      { "name": "Go to shop", "type": "go_to_url", "url": "https://<your-app-url>" },
      { "name": "Click Create Order", "type": "click_element", "selector": "button:nth-child(1)" },
      { "name": "Assert result visible", "type": "assert_element_present", "selector": "#result" }
    ]
  }'
```

### 3.3 View Browser Test Results

1. **Synthetics → Tests** → click your test name
2. Explore:
   - **Filmstrip** — screenshot-by-screenshot playback
   - **Waterfall chart** — every network request and its timing
   - **Web Vitals** — LCP, FID, CLS scores
   - **Run history** — pass/fail over time per location

---

## Module 4 — Synthetic API Tests (Uptime Checks)

API tests check individual HTTP endpoints without a browser — ideal for health checks and SLA monitoring.

### 4.1 Create API Tests for Each Service

#### Test 1 — API Gateway Health

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "API Gateway — Health Check",
    "frequency": 1,
    "locations": ["aws-us-east-1"],
    "active": true,
    "requests": [
      {
        "name": "GET /api/orders",
        "request": {
          "url": "http://<your-app-url>/api/orders",
          "method": "GET",
          "headers": { "Accept": "application/json" }
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" },
          { "type": "RESPONSE_TIME", "comparator": "less_than", "expected": "2000" }
        ]
      }
    ]
  }'
```

#### Test 2 — Order Creation (POST)

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Order Service — Create Order",
    "frequency": 5,
    "locations": ["aws-us-east-1", "aws-ap-southeast-1"],
    "active": true,
    "requests": [
      {
        "name": "POST /api/orders",
        "request": {
          "url": "http://<your-app-url>/api/orders",
          "method": "POST",
          "headers": { "Content-Type": "application/json" },
          "body": "{\"product_id\": 1, \"quantity\": 1}"
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" },
          { "type": "BODY", "comparator": "contains", "expected": "order_id" },
          { "type": "RESPONSE_TIME", "comparator": "less_than", "expected": "3000" }
        ]
      }
    ]
  }'
```

#### Test 3 — Inventory Service

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Inventory Service — Stock Check",
    "frequency": 5,
    "locations": ["aws-us-east-1"],
    "active": true,
    "requests": [
      {
        "name": "GET /api/inventory/1",
        "request": {
          "url": "http://<your-app-url>/api/inventory/1",
          "method": "GET"
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" },
          { "type": "RESPONSE_TIME", "comparator": "less_than", "expected": "1500" }
        ]
      }
    ]
  }'
```

### 4.2 Multi-Step API Test (Chained Requests)

Test a full order flow end-to-end using chained requests with variable extraction:

```bash
curl -X POST "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/api" \
  -H "Content-Type: application/json" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" \
  -d '{
    "name": "Full Order Flow — E2E",
    "frequency": 10,
    "locations": ["aws-us-east-1"],
    "active": true,
    "requests": [
      {
        "name": "Step 1 — Check Inventory",
        "request": {
          "url": "http://<your-app-url>/api/inventory/1",
          "method": "GET"
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" }
        ],
        "extractors": [
          { "type": "JSON_PATH", "source": "BODY", "expression": "$.stock", "variable": "STOCK_COUNT" }
        ]
      },
      {
        "name": "Step 2 — Create Order",
        "request": {
          "url": "http://<your-app-url>/api/orders",
          "method": "POST",
          "headers": { "Content-Type": "application/json" },
          "body": "{\"product_id\": 1, \"quantity\": 1}"
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" },
          { "type": "BODY", "comparator": "contains", "expected": "order_id" }
        ],
        "extractors": [
          { "type": "JSON_PATH", "source": "BODY", "expression": "$.order_id", "variable": "ORDER_ID" }
        ]
      },
      {
        "name": "Step 3 — Verify Order",
        "request": {
          "url": "http://<your-app-url>/api/orders/{{ORDER_ID}}",
          "method": "GET"
        },
        "assertions": [
          { "type": "STATUS", "comparator": "is", "expected": "200" },
          { "type": "BODY", "comparator": "contains", "expected": "{{ORDER_ID}}" }
        ]
      }
    ]
  }'
```

---

## Module 5 — Build a Synthetic + RUM Dashboard

### 5.1 Create a Dashboard in Splunk Observability

1. Navigate to **Dashboards → Create Dashboard**
2. Name it: `Shop Frontend — Synthetic & RUM Overview`

### 5.2 Add These Charts

#### Chart 1 — Synthetic Test Success Rate

```
# SignalFlow
data('synthetics.run.duration', filter=filter('test_name', 'API Gateway — Health Check'))
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
data('rum.page_load.time.ns', filter=filter('app', 'shop-frontend'))
.percentile(pct=75)
.scale(1e-6)   # convert ns to ms
.publish(label='Page Load P75 (ms)')
```

#### Chart 3 — RUM JS Error Rate

```
data('rum.client_error.count', filter=filter('app', 'shop-frontend'))
.sum(over='1m')
.publish(label='JS Errors / min')
```

#### Chart 4 — RUM Long Tasks (Web Vitals)

```
data('rum.long_task.count', filter=filter('app', 'shop-frontend'))
.sum(over='5m')
.publish(label='Long Tasks (5m)')
```

#### Chart 5 — Synthetic vs RUM Response Time Comparison

Add both SignalFlow queries on the same chart:

```
data('synthetics.run.duration', filter=filter('test_name', 'API Gateway — Health Check')).mean().publish(label='Synthetic (External)')
data('rum.xhr.time.ns', filter=filter('app', 'shop-frontend')).percentile(pct=50).scale(1e-6).publish(label='RUM XHR P50 (ms)')
```

### 5.3 Add Detectors (Alerts)

#### Synthetic Alert — Test Failure

1. **Alerts → Create Detector**
2. Use this SignalFlow:

```
from signalfx.detectors.against_recent import against_recent

data('synthetics.run.count', filter=filter('success', 'false'))
  .sum(over='5m')
  .publish('failed_runs')

detect(when(data('synthetics.run.count', filter=filter('success', 'false')).sum(over='5m') > 2))
  .publish('Synthetic Test Failing')
```

#### RUM Alert — High Error Rate

```
detect(
  when(
    data('rum.client_error.count', filter=filter('app', 'shop-frontend'))
      .sum(over='5m') > 10
  )
).publish('High JS Error Rate — shop-frontend')
```

---

## Module 6 — Simulate Errors & Observe Correlation

### 6.1 Inject a Slow Response

Scale down the inventory service to create latency:

```bash
kubectl scale deployment inventory-service -n service-map-lab --replicas=0
```

Wait 2–3 minutes, then observe:
- Synthetic API Test for inventory → starts **failing**
- RUM network requests to `/api/inventory/*` → show **errors or timeouts**
- APM Service Map → inventory-service turns **red**

Restore the service:

```bash
kubectl scale deployment inventory-service -n service-map-lab --replicas=1
```

### 6.2 Inject JavaScript Errors

Open your browser console at `http://localhost:3000` and run:

```javascript
// Simulate an unhandled promise rejection
Promise.reject(new Error("Simulated payment failure"));

// Simulate a runtime error
undefinedFunction();
```

Check **RUM → Errors** — you should see these errors with full stack traces.

### 6.3 Correlate Synthetic → APM Trace

When a Synthetic browser test runs, it injects `traceparent` headers, creating an end-to-end trace:

1. Go to **Synthetics → your browser test → a recent run**
2. Click **View APM trace** on any request
3. This opens the full distributed trace in APM — you can see exactly which service and span was slow

### 6.4 Correlate RUM → APM Trace

RUM automatically links user sessions to backend traces:

1. Go to **RUM → Sessions**
2. Click on a session with errors
3. Click any XHR request → **View trace in APM**
4. The full backend trace for that specific user request opens

---

## Module 7 — Cleanup

```bash
# Remove frontend resources
kubectl delete -f frontend-deployment.yaml
kubectl delete -f frontend-configmap.yaml

# Stop port-forwards
pkill -f "kubectl port-forward"

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
| **RUM Browser Agent** | Injected into frontend via CDN script tag |
| **RUM Metrics** | Page load, XHR timing, JS errors, Web Vitals |
| **Synthetic Browser Test** | Multi-step user journey with assertions |
| **Synthetic API Tests** | Per-service health checks + chained E2E flow |
| **Dashboards** | Combined Synthetic + RUM view in one pane |
| **Detectors** | Alerts on test failure and high JS error rate |
| **Trace Correlation** | Synthetic → APM and RUM session → APM trace |

---

## Reference Links

- [Splunk RUM Browser Instrumentation](https://docs.splunk.com/observability/en/gdi/get-data-in/rum/browser/install-rum-browser.html)
- [Splunk Synthetics Test Types](https://docs.splunk.com/observability/en/synthetics/test-config/test-config.html)
- [Synthetics API Reference](https://dev.splunk.com/observability/reference/api/synthetics/latest)
- [RUM to APM Correlation](https://docs.splunk.com/observability/en/rum/rum-apm-connection.html)
- [SignalFlow Reference](https://dev.splunk.com/observability/docs/signalflow/)

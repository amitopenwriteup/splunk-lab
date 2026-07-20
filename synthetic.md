# Splunk Observability — Synthetic Testing Guide (Apache Tomcat / Rocky Linux)

> **Prerequisites:** Tomcat is running on port `8080` and reachable at a URL your Splunk Synthetics locations can hit (use a public URL or a tunnel such as ngrok if the host is private). You have a Splunk Observability Cloud **API access token** and know your **realm**. If you want APM-linked synthetic runs, the `Server-Timing` response header should already be enabled on the backend (`SPLUNK_TRACE_RESPONSE_HEADER_ENABLED=true`).

**Estimated time:** 20–30 minutes

---

## Overview

| Section | What You'll Do |
|---------|-----------------|
| **Section 1** | Create a Synthetic Browser Test (UI + API) |
| **Section 2** | View Synthetic Browser Test results |
| **Section 3** | Create Synthetic API Tests (uptime checks) |
| **Section 4** | Clean up synthetic tests |

---

## Section 1 — Synthetic Browser Tests

### 1.1 Create a Browser Test via UI

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

### 1.2 Create a Browser Test via API (optional)

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

---

## Section 2 — View Synthetic Browser Test Results

1. **Synthetics → Tests** → click your test name
2. Check the **Waterfall chart** for the request to `/`
3. If the backend `Server-Timing` header is enabled, this run's requests should carry an **APM link** — click through to confirm you land on the correct backend trace

---

## Section 3 — Synthetic API Tests (Uptime Checks)

### 3.1 Homepage Availability Check

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

### 3.2 RUM Bundle Availability Check

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

### 3.3 Server-Timing Header Check

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

### 3.4 Multi-Step API Test (Chained Requests)

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

## Section 4 — Cleanup

```bash
# List all synthetic test IDs
curl -X GET "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>" | jq '.tests[].id'

# Delete a specific test by ID
curl -X DELETE "https://api.<YOUR_REALM>.signalfx.com/v2/synthetics/tests/<TEST_ID>" \
  -H "X-SF-TOKEN: <YOUR_TOKEN>"
```

---

## Summary

| Capability | What Was Configured |
|-----------|---------------------|
| **Synthetic Browser Test** | Homepage journey with content and asset assertions |
| **Synthetic API Tests** | Homepage health check, RUM bundle availability, trace-header check, chained request example |
| **APM Correlation** | Synthetic runs link to backend traces when the `Server-Timing` header is enabled |

---

## Reference Links

- [Splunk Synthetics Test Types](https://docs.splunk.com/observability/en/synthetics/test-config/test-config.html)
- [Synthetics API Reference](https://dev.splunk.com/observability/reference/api/synthetics/latest)

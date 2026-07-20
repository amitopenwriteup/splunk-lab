# Simple Synthetic Testing Lab — Splunk Observability Cloud

**Time:** ~15 minutes
**Goal:** Create one browser test and one API test to monitor a website.

---

## What You Need

- A Splunk Observability Cloud account
- An **API access token** (Settings → Access Tokens)
- Your **realm** (e.g. `us1`, `eu0`)
- A website URL to test (must be publicly reachable)

---

## Step 1 — Create a Browser Test

1. Log in to Splunk Observability Cloud
2. Go to **Synthetics → Create Test → Browser Test**
3. Fill in:

| Field | Value |
|-------|-------|
| Test Name | `My First Browser Test` |
| Locations | Pick 1–2 (e.g. `us-east-1`) |
| Frequency | Every 5 minutes |

> **Note — Where's the URL field?**
> There isn't a separate URL box on this screen. The URL is set inside your first **step**:
> 1. Under **Steps**, click **"Edit steps or synthetic transactions"**
> 2. Add a step → choose **Navigate / Go to URL**
> 3. Enter your website address (e.g. `https://your-website.com`)
> 4. Save the step

4. Add one simple step:

```
Step 1 — Navigate
  Action: go_to
  URL: https://your-website.com
```

5. Click **Save & Run**

✅ **Result:** Splunk will visit your site every 5 minutes and record load time, screenshots, and any errors.

---

## Step 2 — Create an API (Uptime) Test

1. Go to **Synthetics → Create Test → API Test**
2. Fill in:

| Field | Value |
|-------|-------|
| Test Name | `My First API Test` |
| URL | `https://your-website.com` |
| Method | `GET` |
| Locations | Pick 1 |
| Frequency | Every 1 minute |

3. Add an assertion:

```
Status code is 200
```

4. Click **Save & Run**

✅ **Result:** Splunk will check every minute if your site is up and returns a `200` status.

---

## Step 3 — View Results

1. Go to **Synthetics → Tests**
2. Click your test name
3. You'll see:
   - Pass/fail history
   - Response time chart
   - Screenshots (for browser tests)

---

## Step 4 — (Optional) Get Alerted on Failure

1. Open your test
2. Click **Create Detector** (or **Add Alert**)
3. Set condition: `if test fails 2 times in a row`
4. Choose where to send the alert (email, Slack, etc.)
5. Save

---

## Step 5 — Clean Up (When Done)

1. Go to **Synthetics → Tests**
2. Click the **⋯** menu next to your test
3. Select **Delete**

---

## Quick Reference

| Test Type | Checks | Frequency Example |
|-----------|--------|--------------------|
| Browser Test | Full page load, JS errors, screenshots | Every 5 min |
| API Test | Uptime, status code, response time | Every 1 min |

---

## Reference Link

- [Splunk Synthetics Docs](https://docs.splunk.com/observability/en/synthetics/test-config/test-config.html)

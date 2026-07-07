# Workshop: Sending Logs from the Splunk OTel Collector Directly to Splunk Cloud via HEC

## Objective
Configure the Splunk OTel Collector to send logs straight to a Splunk Cloud Platform index using HTTP Event Collector (HEC), by setting environment variables the Collector's `splunk_hec` exporter already references — without editing `agent_config.yaml`.

## Prerequisites
- Admin access to a Splunk Cloud Platform instance
- `sudo` access to the Linux host running the Splunk OTel Collector

## Estimated Time
20–30 minutes

---

## Part A: Splunk Cloud side (full detail)

### Step 1 — Confirm HEC is enabled
HEC is enabled by default on all Splunk Cloud Platform deployments — you don't need a support ticket to turn it on for standard use.

Optional sanity check:
1. Go to **Settings → Data Inputs**.
2. Click **HTTP Event Collector**.
3. Click **Global Settings** (top right).
4. Confirm **All Tokens** is set to **Enabled**.
5. Confirm **Enable SSL** is checked (enabled by default on Splunk Cloud, required for HEC over HTTPS).
6. Note the **HTTP Port Number** (default `8088`) — you'll need this later.
7. Click **Save** if you changed anything.

### Step 2 — Create a dedicated index
Best practice is a new index just for this data, rather than reusing `main` or another existing index.
1. Go to **Settings → Indexes**.
2. Click **New Index** — this opens the **Add new index** dialog.
3. **Name**: enter a clear name, e.g. `obs_cloud_logs`.
4. **Index data type**: leave set to **Events** (not Metrics — this index is for log data).
5. **Max raw data size**: enter `0` for no size limit, or a specific value in MB if you want to cap storage (100MB minimum if you set a limit).
6. **Searchable retention (days)**: enter how long data should stay searchable, e.g. `90` — check with your Splunk admin/storage policy for the right value for your environment.
7. Click **Save**.

> ⚠️ Double-check the index name before saving — specifying an index that doesn't exist later, when configuring the token, can cause silent data loss.

### Step 3 — Create the HEC token
1. Go to **Settings → Data Inputs → HTTP Event Collector** (URL pattern: `https://<your-stack>.splunkcloud.com/en-US/manager/launcher/http-eventcollector`).
2. You'll land on the **HTTP Event Collector** page, showing existing tokens (or "0 Tokens" / "No tokens found" if this is your first one).
3. Click the green **New Token** button (top right, next to **Global Settings**).
4. **Select Source** screen:
   - In the **Name** field, enter a descriptive name, e.g. `obs-cloud-log-forwarding`.
   - *(Optional)* In **Source name override**, set a custom source label for events coming through this token — otherwise Splunk auto-generates one.
   - *(Optional)* In **Description**, note what this token is for.
   - Click **Next**.
5. **Input Settings** screen:
   - Set the **Source Type** to the correct/expected type for this data, or use the default JSON type if unspecified.
   - Under index settings:
     - Set the **Default Index** to the index you created in Step 2 (e.g. `obs_cloud_logs`).
     - Make sure that same index is checked/included in the **Allowed Indexes** list for the token.
   - *(Optional)* If shown, you can enable indexer acknowledgment — but **leave this disabled** since it can negatively affect delivery timeliness.
   - Click **Review**.
6. **Review** screen:
   - Confirm the name, source type, default index, and allowed indexes are all correct.
   - Click **Submit**.
7. **Done** screen:
   - Splunk generates the token and displays the **Token Value** (a GUID, e.g. `a1b2c3d4-...`).
   - **Copy the token value now** and store it securely — you'll export it as an environment variable in Part B. It also remains visible later in the token list under the **Token Value** column if you need to retrieve it again.
8. Back on the **HTTP Event Collector** list page, confirm your new token now appears in the table with the correct **Name**, **Source Type**, **Index**, and a **Status** of enabled.

### Step 4 — Record connection details
Before moving to Part B, make sure you have:
- **HEC URL + port**, e.g. `https://<your-stack>.splunkcloud.com:8088`
- **HEC token value** from Step 3
- **Index name** from Step 2 (for verification later)

---

## Part B: Collector side — export the environment variables (no file edits)

The Collector's default `agent_config.yaml` already includes a `splunk_hec` exporter block under logs that references two environment variables rather than hardcoded values:

```yaml
# Logs
splunk_hec:
  token: "${SPLUNK_HEC_TOKEN}"
  endpoint: "${SPLUNK_HEC_URL}"
  source: "otel"
  sourcetype: "otel"
  profiling_data_enabled: false
```

Because these are already parameterized, you don't need to touch the YAML at all — just set the environment variables the Collector process reads at startup.

### Step 1 — SSH into the host
```bash
ssh user@your-linux-host
```

### Step 2 — Set the environment variables
The Splunk OTel Collector on Linux reads its environment from `/etc/otel/collector/splunk-otel-collector.conf`. Rather than editing `agent_config.yaml`, export the values there:
```bash
sudo tee -a /etc/otel/collector/splunk-otel-collector.conf > /dev/null <<'EOF'
SPLUNK_HEC_TOKEN=c6cf48a8-ebd0-4c93-81e6-bca4e8e8c7b2
SPLUNK_HEC_URL=https://<your-stack>.splunkcloud.com:8088/services/collector
EOF
```
> Replace the token value and `<your-stack>` with your actual values from Part A, Step 4. Note the URL needs the full `/services/collector` path here — not just the base URL/port.

### Step 3 — Verify the variables were added
```bash
sudo grep -E "SPLUNK_HEC_TOKEN|SPLUNK_HEC_URL" /etc/otel/collector/splunk-otel-collector.conf
```
Confirm both lines appear with the correct values.

### Step 4 — Restart the collector to pick up the new values
```bash
sudo systemctl restart splunk-otel-collector
```

### Step 5 — Verify the service is healthy
```bash
sudo systemctl status splunk-otel-collector
```
Expect `active (running)`. If not:
```bash
sudo journalctl -u splunk-otel-collector -n 50 --no-pager
```

### Step 6 — Verify data is arriving in Splunk Cloud
1. Log in to Splunk Cloud, go to **Search & Reporting**.
2. Run:
   ```
   index=obs_cloud_logs
   ```
   (use your actual index name from Part A, Step 2)
3. Set time range to **Last 15 minutes** (or **All time** to rule out a time-range issue).
4. Confirm events appear with `source`/`sourcetype` of `otel` and a recent `_time`.

---

## Part C: If Step 6 shows "0 events" — deeper verification

If the search comes back empty even with **All time** selected, work through these checks in order — most "no data" cases trace back to one of the first three.

### Step 1 — Confirm the env vars actually reached the running process
Appending to the `.conf` file and restarting doesn't always guarantee systemd picked up the change. Check what the live process actually sees:
```bash
sudo cat /proc/$(pgrep -f otelcol | head -1)/environ | tr '\0' '\n' | grep SPLUNK_HEC
```
If this returns nothing, the exported variables never reached the Collector — re-check `EnvironmentFile` wiring:
```bash
sudo systemctl show splunk-otel-collector -p EnvironmentFile
```
This should point to `/etc/otel/collector/splunk-otel-collector.conf`. If it's blank or points elsewhere, that's the root cause.

### Step 2 — Confirm the `splunk_hec` exporter is defined and referenced
```bash
sudo grep -n "splunk_hec" /etc/otel/collector/agent_config.yaml
```
You should see the exporter block defined, and an `exporters: [splunk_hec, splunk_hec/profiling]` line inside a pipeline block further down the file.

### Step 3 — Confirm the `logs:` pipeline actually has a receiver feeding it data
```bash
sudo sed -n '245,265p' /etc/otel/collector/agent_config.yaml
```
Look specifically at the `logs:` block's `receivers:` line, e.g.:
```yaml
logs:
  receivers: [fluent_forward, otlp]
  ...
  exporters: [splunk_hec, splunk_hec/profiling]
```
**This is the most common silent failure.** If `receivers:` only lists things like `fluent_forward` or `otlp`, the pipeline is only listening for logs pushed to it by an external Fluentd/Fluent Bit shipper or an OTLP-native log source — it is **not** tailing any log files on this host by default. With no upstream source actually sending it anything, the pipeline has zero data to export, regardless of whether your HEC token/URL are correct.

### Step 4 — Confirm whether anything is actually connecting to those receivers
```bash
sudo journalctl -u splunk-otel-collector -n 200 --no-pager | grep -i "fluent\|otlp.*log"
```
If there's no sign of an active connection, no log source is feeding the pipeline — this confirms Step 3's diagnosis.

### Step 5 — Fix: add a `filelog` receiver for `/var/log/messages`

Add a `filelog` receiver and include it in the `logs:` pipeline:
```yaml
receivers:
  filelog:
    include: [/var/log/messages]
    start_at: end

service:
  pipelines:
    logs:
      receivers: [fluent_forward, otlp, filelog]
```
Then restart the collector:
```bash
sudo systemctl restart splunk-otel-collector
```

---

## Optional: keep sending profiling data to Observability Cloud too
If your config also has a separate `splunk_hec/profiling` exporter pointed at Observability Cloud, you can leave that as-is and run both exporters side by side — one for regular logs going to Splunk Cloud, one for AlwaysOn Profiling data staying in Observability Cloud. No changes needed there; just confirm both exporters are still referenced under `service: pipelines:` in your config.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| No logs arriving in Splunk Cloud | Token/index mismatch | Confirm token's default index and Allowed indexes list match the target index |
| "0 events" even with All time range | `logs:` pipeline has no receiver actually feeding it data (e.g. only `fluent_forward`/`otlp` with nothing connected) | See Part C above — add a `filelog` receiver or confirm an upstream source is pushing logs in |
| Logs rejected or delayed | Indexer acknowledgment enabled | Disable it on the token |
| Collector fails to restart / logs show empty token or URL | Env variables not exported correctly, or conf file not read | Re-check `/etc/otel/collector/splunk-otel-collector.conf`, confirm exact variable names `SPLUNK_HEC_TOKEN` / `SPLUNK_HEC_URL` |
| Forwarding shows active but nothing appears | Wrong HEC URL/port, or missing `/services/collector` path | Confirm full endpoint path is included in `SPLUNK_HEC_URL` |
| Data appears in wrong index | Allowed indexes / default index mismatch on token | Re-check token config in Splunk Cloud |
| Connection silently rejected despite correct URL/token | Org has restricted the `hec` feature's IP allow list (rare — default is open to all IPs) | Check/update via the ACS API (`adminconfig/v2/access/hec/ipallowlists`) — not available in Splunk Web UI |

---

## Summary
Set up a dedicated index and HEC token in Splunk Cloud, then pointed the Collector's built-in `splunk_hec` exporter at that token/index by exporting `SPLUNK_HEC_TOKEN` and `SPLUNK_HEC_URL` as environment variables — no edits to `agent_config.yaml` required, since the exporter already references those variables by default.

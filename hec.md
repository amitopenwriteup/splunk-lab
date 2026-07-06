# Lab: Verify Your Existing OTel Collector Setup (Splunk Observability Cloud)

**Assumes:** You already have the Splunk Distribution of the OpenTelemetry Collector installed and running on Linux, exporting logs to **Splunk Observability Cloud**. This lab confirms the pipeline is healthy end-to-end and gives you a repeatable way to verify and troubleshoot it — no HEC, no Splunk Enterprise/Cloud Platform involved.

## Lab Overview

By the end of this lab you will:

- Confirm the Collector service is healthy
- Identify exactly what your config is collecting and where it's exporting to
- Generate test log data
- Verify that data in **Log Observer** in Splunk Observability Cloud
- Troubleshoot common issues if data doesn't show up

**Estimated time:** 20–30 minutes

---

## Prerequisites

| Requirement | Details |
|---|---|
| Existing OTel Collector | Already installed and running, exporting to Observability Cloud |
| `sudo` access | On the Collector host |
| Splunk Observability Cloud access | Login to check Log Observer |

---

## Part 1 — Confirm the Collector Is Running

```bash
sudo systemctl status splunk-otel-collector
```

Expected: `active (running)`.

If it's not running, check recent errors before continuing:

```bash
sudo journalctl -u splunk-otel-collector -n 50 --no-pager
```

---

## Part 2 — Confirm What Your Config Is Doing

1. Locate the config file:

   ```bash
   ls /etc/otel/collector/
   ```

2. View the receivers (what's being collected):

   ```bash
   grep -A15 "^receivers:" /etc/otel/collector/agent_config.yaml
   ```

   You're looking for entries like `filelog/...` (log files) and/or `journald` (systemd journal).

3. View the logs pipeline (what's wired together):

   ```bash
   grep -A10 "pipelines:" /etc/otel/collector/agent_config.yaml
   ```

   You should see something like:

   ```yaml
   service:
     pipelines:
       logs:
         receivers: [filelog/myapp, journald]
         processors: [batch]
         exporters: [splunk_hec/o11y]
   ```

4. Confirm the exporter is pointed at Observability Cloud (not a Splunk Enterprise host):

   ```bash
   grep -A5 "exporters:" /etc/otel/collector/agent_config.yaml
   ```

   Confirm the `endpoint:` value looks like:

   ```
   https://ingest.<your-realm>.signalfx.com/v1/log
   ```

   If it instead points at a Splunk Enterprise/Cloud Platform hostname on port `8088`, this lab doesn't apply to your setup — that would be a HEC-based export instead.

5. Confirm your access token and realm are set correctly in the environment file:

   ```bash
   cat /etc/otel/collector/splunk-otel-collector.conf
   ```

   Confirm `SPLUNK_ACCESS_TOKEN` and `SPLUNK_REALM` are populated (not blank or placeholder values).

**Checkpoint:** You should now know exactly which file(s) get collected and which Observability Cloud realm they're sent to.

---

## Part 3 — Generate Test Log Data

If you're using the sample `filelog/myapp` receiver from earlier setup:

```bash
sudo mkdir -p /var/log/myapp
for i in {1..5}; do
  echo "$(date -Iseconds) INFO verification test event $i" | sudo tee -a /var/log/myapp/app.log
  sleep 1
done
```

If you're collecting a different file or `journald`, generate activity relevant to that source instead — e.g., trigger an SSH login or `sudo` command for `journald`.

---

## Part 4 — Verify in Splunk Observability Cloud

1. Log in to Splunk Observability Cloud.
2. Go to **Log Observer**.
3. Filter by:
   - `host.name` = your Linux host's hostname (run `hostname` on the box to confirm)
   - and/or `sourcetype` matching what your config sets (check the `sourcetype:` field in the exporter block from Part 2 step 4)
4. Set the time range to the last 15 minutes.
5. Confirm your test events from Part 3 appear.

**Checkpoint question:** If events don't appear in Log Observer but the Collector service shows `active (running)` with no errors, what's the next thing to check?
<details>
<summary>Answer</summary>
Check that the search filters (host name, sourcetype, time range) actually match what the Collector is sending — a healthy pipeline with a mismatched filter is the most common reason for "nothing showing up."
</details>

---

## Part 5 — Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Collector not running | Config error or resource limits | `sudo journalctl -u splunk-otel-collector -n 50 --no-pager`; restore last known-good config if needed |
| No events at all in Log Observer | Wrong `SPLUNK_ACCESS_TOKEN` or `SPLUNK_REALM` | Recheck `/etc/otel/collector/splunk-otel-collector.conf` values against your Observability Cloud org settings |
| Some events missing (gaps) | `filelog` receiver started mid-file, or file rotated | Confirm `start_at: beginning` is set for a fresh read, or check for log rotation truncating the file |
| Events appear with wrong host/sourcetype | Defaults set on the exporter differ from what you expect | Check `source:`/`sourcetype:` fields under the exporter block in `agent_config.yaml` |
| `permission denied` reading log file | Collector service user lacks read access | `sudo systemctl show splunk-otel-collector -p User -p Group` then adjust file/group permissions accordingly |
| Duplicate events after a restart | Expected without persistent offset storage (optional feature, not required for collection) | Not an error — see prior lab notes on `file_storage` if you want to eliminate this |

**Quick local sanity check** (temporarily add a debug exporter to confirm the pipeline is emitting records at all, independent of Observability Cloud):

```yaml
exporters:
  logging:
    verbosity: detailed

service:
  pipelines:
    logs:
      exporters: [logging, splunk_hec/o11y]
```

```bash
sudo systemctl restart splunk-otel-collector
journalctl -u splunk-otel-collector -f | grep -A5 "LogRecord"
```

Remove the `logging` exporter again once you've confirmed the pipeline is emitting data — it's for debugging only and adds noise to local logs.

---

## Summary

You confirmed your existing Collector is healthy, verified what it's collecting and where it's exporting to, generated test data, and confirmed it lands in Log Observer in Splunk Observability Cloud — with a troubleshooting path for the common ways this can silently fail.

## Further Reading

- [Collect logs with the Collector for Linux](https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/collector-for-linux/collect-logs-with-the-collector-for-linux)
- [Collector for Linux default configuration](https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/collector-for-linux/collector-for-linux-default-configuration)
- [Advanced configuration for Linux](https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/collector-for-linux/advanced-configuration-for-linux)
- [Troubleshooting](https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/troubleshooting)

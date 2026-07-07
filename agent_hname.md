# Lab: Overriding the Reported Hostname in Splunk Observability Cloud

## Objective
By the end of this lab, you will be able to override the `host.name` attribute reported by the Splunk OpenTelemetry (OTel) Collector on a Linux host, so that a custom hostname appears in Splunk Observability Cloud instead of the auto-detected system hostname.

## Prerequisites
- A Linux host with the Splunk OTel Collector already installed
- `sudo` access on that host
- Config file located at `/etc/otel/collector/agent_config.yaml`
- Basic familiarity with YAML and the Linux command line

## Estimated Time
15–20 minutes

---

## Step 1: SSH into the host running the collector
```bash
ssh user@your-linux-host
```

## Step 2: Back up the existing config
Always back up before editing.
```bash
sudo cp /etc/otel/collector/agent_config.yaml /etc/otel/collector/agent_config.yaml.bak
```

## Step 3: View the current config
Look at the full file, or just the relevant section:
```bash
sudo cat /etc/otel/collector/agent_config.yaml
```
```bash
sudo grep -n "resourcedetection" -A 5 /etc/otel/collector/agent_config.yaml
```

## Step 4: Open the file for editing
```bash
sudo nano /etc/otel/collector/agent_config.yaml
```
(Use `vim` instead of `nano` if you prefer.)

## Step 5: Add a processor to set the hostname
Under the `processors:` section, add a new processor block:
```yaml
processors:
  resource/hostname_override:
    attributes:
      - key: host.name
        value: "your-new-hostname"
        action: upsert
```

> **What does `action: upsert` mean?**
> It means **update or insert** — the processor sets `host.name` to your value no matter what, overwriting it if it already exists or adding it if it doesn't. This guarantees your custom value always wins.

Keep all existing processors already in the file — this is added alongside them, not in place of them.

## Step 6: Prevent `resourcedetection` from overriding your value
Find the existing `resourcedetection` processor and set `override: false` so it doesn't clobber the value you just set:
```yaml
  resourcedetection:
    detectors: [system, env, gce, ec2]
    override: false
```

## Step 7: Add your new processor to the pipelines
Find the `service: > pipelines:` section near the bottom of the file. Add `resource/hostname_override` to the processor list — placed **before** `resourcedetection` — for both the `metrics` and `traces` pipelines:
```yaml
service:
  pipelines:
    metrics:
      processors:
        - memory_limiter
        - resource/hostname_override
        - resourcedetection
        - batch
    traces:
      processors:
        - memory_limiter
        - resource/hostname_override
        - resourcedetection
        - batch
```

## Step 8: Save and exit
- **nano**: `Ctrl+O`, then `Enter`, then `Ctrl+X`
- **vim**: `Esc`, then type `:wq`, then `Enter`

## Step 9: Restart the collector service
```bash
sudo systemctl restart splunk-otel-collector
```

## Step 10: Verify the service started cleanly
```bash
sudo systemctl status splunk-otel-collector
```
Expected output should show `active (running)`.

If it failed to start, check the logs:
```bash
sudo journalctl -u splunk-otel-collector -n 50 --no-pager
```

## Step 11: Verify in Splunk Observability Cloud
1. Wait 2–5 minutes for new metrics to arrive.
2. In Splunk Observability Cloud, go to **Infrastructure → Hosts**.
3. Search for your new hostname — it should now appear with incoming data.
4. Note: the old hostname will show as **inactive/missing**, not renamed. Historical data stays associated with the old hostname.

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| New hostname doesn't appear | Collector didn't restart properly | Re-check `systemctl status`, review logs |
| YAML parse errors on restart | Indentation issue in config | Compare indentation carefully against examples above; YAML is whitespace-sensitive |
| Old hostname still reporting | `resourcedetection` still set to `override: true`, or processor order wrong | Confirm `override: false` and that `resource/hostname_override` comes before `resourcedetection` in the pipeline list |
| No data at all after change | Typo in processor name/reference | Ensure the processor name in `processors:` exactly matches the name used in `pipelines:` |

## Cleanup / Rollback
If you need to revert:
```bash
sudo cp /etc/otel/collector/agent_config.yaml.bak /etc/otel/collector/agent_config.yaml
sudo systemctl restart splunk-otel-collector
```

---

## Summary
You added a `resource` processor with `action: upsert` to force a custom `host.name` value, disabled auto-override from `resourcedetection`, and confirmed the change took effect in Splunk Observability Cloud's Infrastructure view.

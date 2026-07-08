# Lab Part 2 (Exercise 7): Tagging the Host in Splunk Observability Cloud

**Objective:** Add custom tags/dimensions (e.g. `team`, `env`, `role`) to the host your Splunk OTel Collector is reporting from, so you can filter and group it in Infrastructure views, dashboards, and detectors.

**Estimated time:** 10–15 minutes

**Prerequisite:** Completed `lab-otel-collector-windows-part1.md` — collector installed as a Windows service and host metrics already visible in **Infrastructure → Hosts**.

**Environment:** Same Windows 10 machine, elevated PowerShell, `$SplunkRealm` / `$SplunkAccessToken` still set (re-set them if you opened a new session)

---

## Two ways to tag a host

| Method | When to use it |
|---|---|
| **A. Reinstall with tags** | Simplest — good if you're okay re-running the installer |
| **B. Edit the config directly** | No reinstall needed; better once you're past the lab and managing config in place |

This lab walks through both so you can see how they relate — Method A is really just a shortcut that writes the same thing Method B does by hand.

---

## Method A — Set tags via the installer

The install script accepts a `-tags` parameter (comma-separated `key:value` pairs) alongside `-deployment_environment`, which itself is just a shortcut for the `deployment.environment` tag.

### Step 1 — Re-run the installer with tags

```powershell
& "$env:TEMP\splunk-otel-collector.ps1" `
  -access_token $SplunkAccessToken `
  -realm $SplunkRealm `
  -mode "agent" `
  -deployment_environment "lab" `
  -tags "team:web,role:otel-lab-vm"
```

The installer detects the existing service, updates the config in place, and restarts it — you don't lose your Exercise 1–3 setup.

### Step 2 — Confirm the service restarted

```powershell
Get-Service splunk-otel-collector
```

**Expected result:** `Status` is `Running` (it will briefly show `Stopped`/`Starting` during the reinstall).

Skip to **Validate in the UI** below, or continue to Method B to see what changed under the hood.

---

## Method B — Edit `agent_config.yaml` directly

### Step 1 — Open the config

```powershell
notepad "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
```

### Step 2 — Find the `resource` processor

The default config already includes a `resourcedetection` processor (auto-detects things like hostname and OS). Tags you set manually go in a `resource` processor, which adds or overrides attributes. Look for a block similar to:

```yaml
processors:
  resourcedetection:
    detectors: [system]
    override: true
  resource:
    attributes:
      - key: deployment.environment
        value: "lab"
        action: upsert
```

If `resource` isn't already there, add it under `processors:`, adding one `- key / value / action: upsert` entry per tag:

```yaml
  resource:
    attributes:
      - key: deployment.environment
        value: "lab"
        action: upsert
      - key: team
        value: "web"
        action: upsert
      - key: role
        value: "otel-lab-vm"
        action: upsert
```

### Step 3 — Wire the processor into the metrics pipeline

Still in the same file, find the `service:` → `pipelines:` → `metrics:` section and make sure `resource` is listed in `processors:`, after `resourcedetection`:

```yaml
service:
  pipelines:
    metrics:
      receivers: [hostmetrics, windowsperfcounters]
      processors: [resourcedetection, resource, batch]
      exporters: [signalfx]
```

> Order matters here: `resourcedetection` runs first and populates defaults, `resource` runs second and can overwrite them with your values (that's what `action: upsert` does).

### Step 4 — Save and restart the service

```powershell
Restart-Service splunk-otel-collector
Get-Service splunk-otel-collector
```

**Expected result:** `Status` shows `Running`.

### Step 5 — Watch for config errors

```powershell
Get-Content "C:\ProgramData\Splunk\OpenTelemetry Collector\logs\otelcol.log" -Tail 30
```

A bad YAML indent here is the most common mistake — if the service fails to come back up, this log will show a parsing error pointing at the line number.

---

## Validate in the UI

1. In Splunk Observability Cloud, go to **Infrastructure → Hosts**.
2. Click into your host (search by hostname, same as Exercise 3).
3. Open the **Metadata** or **Properties** panel — you should see `team: web`, `role: otel-lab-vm`, and `deployment.environment: lab` listed as dimensions.
4. Go to any chart or the host list and use the filter bar to search `team:web` — your host should appear.

### Checkpoint questions
- What's the difference between what `resourcedetection` sets automatically and what `resource` lets you override?
- Why does `action: upsert` matter here instead of `insert`? (Hint: what would happen if `resourcedetection` already set a value for that same key?)

---

## Part 2 (Exercise 7) Checkpoint

| Component | Status |
|---|---|
| Tags applied via installer or config edit | ✅ |
| Collector service running after change | ✅ |
| No errors in `otelcol.log` | ✅ |
| Custom tags visible on host in Infrastructure → Hosts | ✅ |

**Next:** Continue with Exercise 8 (alerting) in `lab-otel-collector-windows-part2.md`.

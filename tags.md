# Lab : Tagging Hosts with `deployment.environment` and Custom Attributes

**Objective:** Use the OpenTelemetry `deployment.environment` attribute (not a generic "environment" tag) plus custom resource attributes to tag your host, using the Collector's **Resource processor** — the method Splunk's official docs recommend.

**Estimated time:** 15 minutes

**Prerequisite:** Completed `lab-otel-collector-windows-part1.md` — collector installed and running as a Windows service, host metrics visible in **Infrastructure → Hosts**.

**Reference:** [Use tags or attributes in OpenTelemetry](https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/get-started-understand-and-use-the-collector/use-tags-or-attributes-in-opentelemetry) and [Resource processor](https://help.splunk.com/en/splunk-observability-cloud/manage-data/splunk-distribution-of-the-opentelemetry-collector/get-started-with-the-splunk-distribution-of-the-opentelemetry-collector/collector-components/processors/resource-processor)

---

## Why `deployment.environment` specifically

`deployment.environment` is a standardized OpenTelemetry attribute (not a free-form tag). Splunk Observability Cloud uses this exact name to power **Related Content** links between Infrastructure and APM — a custom tag like `environment` or `env` won't get that linking.

---

## Step 1 — Open the agent config

```powershell
notepad "C:\ProgramData\Splunk\OpenTelemetry Collector\agent_config.yaml"
```

## Step 2 — Add a `resource` processor

Find the `processors:` section. Add (or extend) a `resource` block. Each entry needs a `key`, a `value`, and an `action`:

```yaml
processors:
  resourcedetection:
    detectors: [system]
    override: true

  resource:
    attributes:
      - key: deployment.environment
        value: "staging"
        action: upsert
      - key: team
        value: "web"
        action: upsert
```

- `action: upsert` adds the attribute if it's missing, or overwrites it if `resourcedetection` (or anything else) already set a value for that key.
- Other available actions include `insert` (only if the key doesn't already exist) and `delete` (remove a key) — `upsert` is the right default when you want your value to win.

## Step 3 — Wire `resource` into the pipelines

Still in the same file, under `service: → pipelines:`, make sure `resource` is listed in the `processors:` list for the pipelines you want tagged — typically both `metrics` and `traces`:

```yaml
service:
  pipelines:
    metrics:
      receivers: [hostmetrics, windowsperfcounters]
      processors: [resourcedetection, resource, batch]
      exporters: [signalfx]

    traces:
      receivers: [otlp]
      processors: [resourcedetection, resource, batch]
      exporters: [sapm]
```

> Order matters: `resourcedetection` runs first and fills in defaults (like hostname), `resource` runs second and applies your `upsert`/`insert`/`delete` actions on top.

## Step 4 — Save and restart the service

```powershell
Restart-Service splunk-otel-collector
Get-Service splunk-otel-collector
```

**Expected result:** `Status` shows `Running`.

## Step 5 — Check for config errors

```powershell
Get-Content "C:\ProgramData\Splunk\OpenTelemetry Collector\logs\otelcol.log" -Tail 30
```

A YAML indentation mistake is the most common failure here — the log will point at the offending line if the service won't come back up.

---

## Validate in the UI

1. Go to **Infrastructure → Hosts** in Splunk Observability Cloud and open your host.
2. Check the **Metadata**/**Properties** panel for `deployment.environment: staging` and `team: web`.
3. Go to **APM** (if you completed the traces exercise) and confirm a service on this host now shows a **Related Content** link back to its Infrastructure host — this only appears when `deployment.environment` is set correctly.
4. Use the filter bar on any chart or host list and search `deployment.environment:staging` to confirm the host is discoverable.

---

## Part 2 (Exercise 7) Checkpoint

| Component | Status |
|---|---|
| `resource` processor added with `deployment.environment` (upsert) | ✅ |
| `resource` processor included in metrics/traces pipelines | ✅ |
| Collector restarted with no errors in `otelcol.log` | ✅ |
| `deployment.environment` and custom attributes visible on host in UI | ✅ |
**Next:** Continue with Exercise 8 (alerting) in `lab-otel-collector-windows-part2.md`.

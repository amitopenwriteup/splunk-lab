# Integrating Splunk On-Call with Splunk Observability Cloud

This guide covers the full setup: creating an API/integration key in Splunk On-Call, creating a routing key, creating the VictorOps integration in Splunk Observability Cloud, and mapping it as a detector notification recipient.

---

## 1. Create the Integration Key in Splunk On-Call

The integration key (API endpoint) is what allows external systems — including Splunk Observability Cloud — to send alerts into Splunk On-Call.

1. Log in to Splunk On-Call (`portal.victorops.com`).
2. Go to **Integrations → 3rd Party Integrations**.
3. Search for **Splunk Observability Cloud System Monitoring** (or **REST Endpoint** if not listed by that exact name).
4. Select **Enable Integration**.
5. Copy the generated **Service API Endpoint URL**. It looks like:

   ```
   https://alert.victorops.com/integrations/generic/20131114/alert/<your_api_key>/$routing_key
   ```

6. Keep this URL — you'll paste it into Splunk Observability Cloud in Step 3.

> **Note:** If you don't see an endpoint URL, select **Enable Integration** to generate one.

---

## 2. Create a Routing Key in Splunk On-Call

Routing keys let you direct alerts to specific teams/escalation policies using the same integration.

1. In Splunk On-Call, go to **Settings → Routing Keys**.
2. Select **Add Key**.
3. Fill in:
   - **Name** — letters, numbers, hyphens, and underscores only (case insensitive), e.g. `infra-team`, `k8s-alerts`.
   - **Multi-Responder** (optional) — if checked, requires an acknowledgment from a member of *each* assigned escalation policy before the incident is fully acknowledged.
4. **Assign the routing key to at least one Escalation Policy** — this is required.
5. Save.

You can create multiple routing keys to fan alerts out to different teams using the same integration endpoint from Step 1.

---

## 3. Create the VictorOps Integration in Splunk Observability Cloud

> In Observability Cloud's UI, Splunk On-Call is listed as **VictorOps** (legacy product name).

1. Log in to **Splunk Observability Cloud**.
2. Go to **Data Management** (left nav).
3. Open the **Available Integrations** tab (or select **Add Integration** from **Deployed Integrations**).
4. In the integration filter, select **All**, then search for **VictorOps**.
5. Select **Add Integration** / **New Integration**.
6. Paste in the **Service API Endpoint URL** you copied in Step 1.
7. Give the integration a clear, descriptive **name** (e.g. `SplunkOnCall-Prod`) — this is the name you'll pick later when adding it as a recipient.
8. Save.

---

## 4. Map the Integration to a Detector Notification

Once the VictorOps integration exists at the org level, it becomes selectable as a recipient type on any detector.

1. Open or create the **Detector** you want to alert on.
2. Go to the **Alert Recipients** step → select **Add Recipient**.
3. Choose **VictorOps** from the recipient type list.
4. Select the integration name you created in Step 3.
5. Enter the **routing key** you created in Step 2.
6. **Activate** and save the detector.

---

## 5. Test the Configuration

- Trigger the detector manually or wait for the condition to fire.
- Check the **Splunk On-Call Timeline** (not just Incidents) for the test alert — test/INFO-level alerts show in the timeline, not as incidents.
- Confirm the alert clears/resolves in On-Call when the detector condition clears.

---

## Troubleshooting

| Symptom | Likely Cause |
|---|---|
| Only Email/Team/Webhook show as recipient types | VictorOps integration hasn't been created yet under **Data Management → Integrations** |
| Slack tile missing/won't authorize in Splunk On-Call | Requires **Slack Admin/Primary Owner** rights on the Slack workspace, not just On-Call admin rights |
| Routing key rejected | Check for spaces or special characters — only letters, numbers, hyphens, underscores are allowed |
| No incident created, only appears in Timeline | Alert was sent as `INFO` severity — change to `CRITICAL`/`WARNING` to generate an incident |
| Integration created but not selectable on detector | Recipient list may need a refresh — reopen the detector's Alert Recipients step |

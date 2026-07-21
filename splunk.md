# Slack Integration – Splunk Observability Cloud

## Step 1: Create a Slack Integration
1. Log in to Splunk Observability Cloud.
2. Open the Slack guided setup (or navigate manually):
   - In the left navigation menu, select **Data Management**.
   - Go to the **Available Integrations** tab (or select **Add Integration** in the **Deployed Integrations** tab).
   - In the integration filter menu, select **All**.
   - In the **Search** field, search for **Slack** and select it.
3. Select **New Integration** to open the configuration options.
4. Complete the guided setup to authorize Splunk Observability Cloud to post to your Slack workspace.

> **Requirement:** You must be a Splunk Observability Cloud administrator, a Slack administrator, and authorized to add apps to Slack.

## Step 2: Add the Slack Integration as a Detector Alert Recipient
1. Create or edit the detector you want to send Slack notifications for.
2. In the **Alert Recipients** step, select **Add Recipient**.
3. Select **Slack**, then choose the Slack integration name you created in Step 1.
4. Specify the channel:
   - **Public channel:** Enter the channel name.
   - **Private channel:** Invite the SignalFx app first — in Slack, go to the private channel and run:

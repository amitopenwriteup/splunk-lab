# Lab: Trigger Scripts on Problem – Splunk On-Call (Alert Rules Engine)

## Overview
This lab walks through configuring the Splunk On-Call **Alert Rules Engine** to trigger a custom action (script/webhook) when an incoming alert matches a condition — commonly referred to as "trigger scripts on problem."

> **Availability Note:** The Alert Rules Engine is an **Enterprise-tier** feature of Splunk On-Call. It may **not** be included in the standard 14-day free trial. Before starting this lab, confirm with Splunk support/sales whether your trial account includes Rules Engine access.

---

## Prerequisites
- Active Splunk On-Call account (trial or licensed)
- Admin access to Settings
- A test integration already sending alerts into Splunk On-Call (e.g., REST Endpoint, email, or a monitoring tool integration)
- (Optional) An external endpoint to receive a webhook call — e.g., a webhook testing tool like RequestBin or a simple HTTP listener script

---

## Lab Objective
By the end of this lab, you will:
1. Create a Rules Engine rule
2. Define a matching condition based on an incoming alert field
3. Configure an action to trigger when the condition is met (e.g., custom outbound webhook, annotation, or suppression)
4. Test the rule by firing a sample alert

---

## Step 1: Verify Feature Access
1. Log in to Splunk On-Call.
2. Navigate to **Settings**.
3. Look for **Alert Rules Engine** in the menu.
   - If present → proceed to Step 2.
   - If absent → your trial/plan does not include this feature. Contact Splunk support to request a trial upgrade.

---

## Step 2: Create a New Rule
1. Go to **Settings → Alert Rules Engine**.
2. Select **Add a Rule**.
3. You'll see two sections in the rule editor:
   - **Top section:** Matching Condition (when the rule applies)
   - **Bottom section:** Actions (what happens when matched)

---

## Step 3: Define the Matching Condition
1. Choose a field to match against an incoming alert, such as:
   - `entity_id`
   - `message_type` (e.g., CRITICAL, WARNING)
   - `state_message`
   - Monitoring tool name
2. Set the condition operator (equals, contains, regex match, etc.).
3. Enter the value to match — for example:

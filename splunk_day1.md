# Signing Up for Splunk Observability Cloud (E2)

Splunk Observability Cloud (sometimes referred to internally as "E2") offers two ways to get started: a **Free Edition** (ongoing access, up to 15 hosts, no credit card) and a **14-day Free Trial** (full platform, time-limited). Steps below cover the Free Edition sign-up, which is the recommended starting point.

## Prerequisites

- A valid business email address
- Company name and job title
- No credit card required

## Steps

1. **Go to the sign-up page**
   Visit [splunk.com/en_us/download/observability-cloud-free-edition.html](https://www.splunk.com/en_us/download/observability-cloud-free-edition.html)

2. **Select your region**
   Choose where you'd like your account hosted:
   - United States
   - Europe (Ireland)
   - Europe (Frankfurt)
   - Europe (London)
   - Asia Pacific (Australia)
   - Asia Pacific (Japan)
   - Asia Pacific (Singapore)

   Click **Next**.

3. **Enter your personal details**
   - First Name
   - Last Name
   - Business Email
   - Job Title
   - Phone Number

4. **Enter your company details**
   - Company name
   - Country
   - Zip / Postal Code

5. **Submit the form**
   Click **Start Free Edition**.

6. **Check your email**
   You'll see a confirmation message: *"Thank you for registering. Your free edition account is on its way!"*
   An activation email arrives within **10 minutes** (check spam/junk if it doesn't show up).

7. **Activate and log in**
   Open the email and follow the link to set your password and log in to your new Splunk Observability Cloud organization.

8. **Locate your realm and access token**
   Once logged in, note your **realm** (region identifier) and generate an **access token** — both are required later to connect data sources (e.g., the OpenTelemetry Collector).
   Path: **Settings → Access Tokens**

9. **Start sending data**
   From the home page, use the **Data Integrations** page to instrument your environment (OpenTelemetry Collector, sample apps, or existing infrastructure).

## Alternative: 14-Day Free Trial

If you prefer the guided trial experience instead (uses a sample "Hipster Shop" app or your own OpenTelemetry data):

1. Go to [splunk.com/en_us/download.html](https://www.splunk.com/en_us/download.html)
2. Create a Splunk account (or log in if you already have one)
3. Select **Splunk Observability Cloud trial** (14 days)
4. Follow the guided onboarding to set up prerequisites: Docker, minikube, Helm, and GNU sed
5. Deploy the sample environment or connect your own app via OpenTelemetry
6. Generate traffic and explore dashboards, APM, and Infrastructure Monitoring

## Notes

- No credit card is required for either option.
- The Free Edition does not expire but is capped at 15 monitored hosts.
- The Trial gives full access for 14 days with no host cap, ideal for a broader proof-of-concept.
- For team/enterprise access beyond the free tiers, contact Splunk Sales.

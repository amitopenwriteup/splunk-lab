# Lab: Splunk Cloud Free Trial — Manual Setup & Linux Log Forwarding

### Sign up, configure the cloud stack, then install and wire up a Universal Forwarder on Rocky Linux — every step done by hand, no scripts.

**Duration:** ~2–2.5 hours
**Environment:** Splunk Cloud Platform (free trial) + one Rocky Linux host (physical, VM, or cloud instance)
**Audience:** Anyone standing up Splunk Cloud for the first time and onboarding a Linux server's logs manually

---

## What You'll End With

- A live Splunk Cloud trial stack you can log into
- A Universal Forwarder installed and running on a Rocky Linux machine
- That forwarder correctly authenticated and sending data to your Splunk Cloud stack
- **A real application (Apache/httpd) installed and generating logs**, monitored and forwarded using Splunk's built-in `access_combined` sourcetype
- A second, hand-written JSON log source monitored in parallel, to see custom-format onboarding too
- Events from both sources visible and searchable in Splunk Cloud

No Python, no shell scripts, no config management — every step is a manual action in a terminal or browser so you understand exactly what each piece does.

---

## Part 1 — Sign Up for Splunk Cloud Free Trial

### Step 1.1 — Start the Trial

1. Open a browser and go to: `https://www.splunk.com/en_us/download/splunk-cloud-platform.html` (or search "Splunk Cloud free trial" if the URL has moved).
2. Click **Free Trial** / **Get Started**.
3. Fill in the signup form: work email, name, company, country.
4. Submit. You'll receive a confirmation email — click the verification link inside it.

### Step 1.2 — Provision Your Stack

1. After verifying your email, Splunk provisions a dedicated **trial stack**. This takes a few minutes.
2. You'll receive a second email once the stack is ready, containing:
   - Your stack URL, e.g. `https://prd-p-xxxxx.splunkcloud.com`
   - Your initial admin username and a temporary password
3. Open the stack URL and log in with those credentials.
4. On first login, Splunk will prompt you to **set a new password** — do this now and store it somewhere safe (password manager). You will use this login for the entire lab.

> **Note:** Free trials are typically time-boxed (commonly 14 days) and capped on daily indexing volume. Check the **Settings → License** page after logging in to see your exact trial limits so you don't get surprised mid-lab.

### Step 1.3 — Explore the Landing Page

Once logged in, you should see the **Splunk Cloud Platform home page** with apps listed on the left, including:
- **Search & Reporting**
- **Apps → Manage Apps**
- A **Settings** gear icon top-right

Confirm you can click into **Search & Reporting** and see an empty search bar — this confirms your search head access works before we touch any Linux machine.

---

## Part 2 — Configure Splunk Cloud (Manual, Browser-Only Steps)

Do all of these steps in the Splunk Cloud web UI before touching the Linux box.

### Step 2.1 — Create the Index

1. Click the **Settings** gear (top right) → **Indexes**.
2. Click **New Index**.
3. Fill in:
   - **Index Name**: `api_logs`
   - **Index Data Type**: Events
   - Leave retention/size settings at their defaults for the trial.
4. Click **Save**.
5. Confirm `api_logs` now appears in the index list with status **Enabled**.

### Step 2.2 — Add Your Linux Host's IP to the Network Allow List

This step is mandatory — without it, Splunk Cloud will silently reject connections from your Linux machine later.

1. Click the **Settings** gear icon (top right).
2. Go to **Servier -> Secrets management → Network allow list** (breadcrumb shows `Secrets management / Network allow list`).
3. You'll see a list of existing entries — by default there's often a `*` wildcard entry present. You can leave `*` in place during the trial (it means "allow from anywhere"), or remove it later and lock things down to specific IPs once you're done testing.
4. Find your Linux machine's **public IP address**. If you don't know it, run this on the Linux host:
   ```bash
   curl ifconfig.me
   ```
   Copy the IP it prints.
5. Click **+ Add network**, and enter that IP into the new text field (e.g., `49.43.35.253`). You can enter a single IPv4/IPv6 address, a CIDR block (e.g., `49.43.35.0/24`), or a DNS name. Prefixing an entry with `!` explicitly **blocks** that network instead of allowing it.
6. The page auto-saves each entry as you add it (no separate "Save" button) — confirm your new IP appears in the list alongside any existing entries, then click the trash-can icon next to any entry you want to remove (e.g., removing the `*` wildcard once you've added your specific IP, if you want to tighten access).

> **Note:** This particular allow list (under **Secrets management**) governs network access to Splunk Cloud generally, including clear-text secrets/API access. Depending on your stack version, **HEC** and **forwarder (S2S/9997)** traffic may share this same allow list, or may have their own separate allow list under **Settings → Data Inputs → HTTP Event Collector** (for HEC) or **Settings → Forwarder Management** (for S2S). If your forwarder or HEC test later fails to connect even after adding your IP here, check those sections too for a second, traffic-specific allow list.

### Step 2.3 — Download the Universal Forwarder Credentials Package

Splunk Cloud requires a stack-specific credentials package to let a Universal Forwarder authenticate — you cannot point a UF at Splunk Cloud with just a plain hostname and port.

1. From the top navigation bar (not Settings), go to **Apps → Universal Forwarder**. This is a dedicated app pre-installed on every Splunk Cloud stack that walks through a 5-step checklist: download UF, install UF, download credentials, install credentials, configure inputs.
2. You only need **step 3** of that checklist right now: click the green **Download Universal Forwarder Credentials** button.
3. This downloads a small package named `splunkclouduf.spl`.
4. Save this file somewhere you can retrieve it from — you'll transfer it to the Linux machine in Part 3. **Do not open or extract it yet.**

> The page's steps 1, 2, 4, and 5 (download/install the UF binary, install the credentials package, configure inputs) are the same actions this lab walks you through manually in Parts 3 and 4 — you don't need to follow their linked instructions separately, just use this lab's steps.

> If you don't see **Universal Forwarder** listed under **Apps**, click **Apps → Manage Apps** and check if it's installed but hidden from the main nav — it ships by default on Splunk Cloud, so it should be there. You can also reach the same page directly at:
> ```
> https://<your-stack-name>.splunkcloud.com/en-US/app/splunkclouduf/setupuf
> ```

### Step 2.4 — Note Your Forwarder Input Endpoint

The **Universal Forwarder** app page itself (shown above) doesn't display the receiving endpoint directly — it's a 5-step checklist (Download UF → Install UF → Download credentials → Install credentials → Configure inputs), not a settings page. You'll actually see the exact endpoint two ways:

1. **After downloading the credentials package** (next step), the endpoint is embedded inside it — you'll confirm it in Part 3, Step 3.8, when you inspect `outputs.conf` on the Linux host after installing the package. That's the authoritative source, since it's stack-specific.
2. As a preview, it typically follows this pattern based on your stack name:
   ```
   inputs<your-stack-id>.splunkcloud.com:9997
   ```
   For example, if your stack URL is `https://prd-p-abc123.splunkcloud.com`, the forwarder input endpoint is usually `inputs-prd-p-abc123.splunkcloud.com:9997`. Treat this as a guess to sanity-check against, not a value to hardcode — verify it from `outputs.conf` once you have the real credentials package installed.

You can proceed straight to Step 2.5 (or Part 3) now — there's nothing more to note on this page itself.

### Step 2.5 — Create a HEC Token (Optional Alternate Path)

If you'd rather test with HEC instead of, or in addition to, the Universal Forwarder:

1. **Settings → Data Inputs → HTTP Event Collector**.
2. If HEC is not yet enabled, click **Global Settings**. In the **Edit Global Settings** dialog, set **All Tokens** to **Enabled**, optionally set a **Default Source Type** and **Default Index**, keep **Enable SSL** checked, and note the **HTTP Port Number** field (defaults to `8088`). Click **Save**.
   > This dialog is also just config — like the token confirmation screen, **it does not show your HEC URI either**, only the port number Splunk listens on. The full endpoint has to be constructed by hand (Step 8 below) since Splunk Cloud's web console doesn't display it anywhere in the UI.
   > Double check any typed values here — e.g. if you're reusing a **Default Source Type**, make sure it's spelled `api_json`, not `api_josn` or similar, since a typo here silently creates/uses a different sourcetype than the one you intend.
3. Click **New Token** — this launches an **Add Data** wizard with four stages: **Select Source → Input Settings → Review → Done**.
4. **Select Source**: name the token (e.g., `lab-api-hec`), click **Next**.
5. **Input Settings**: set **Source type** → **New** → type `api_json`. Set **Index** → `api_logs`. Click **Review**.
6. **Review**: confirm the settings, click **Submit**.
7. **Done**: you'll land on a confirmation screen reading **"Token has been created successfully."** with a **Token Value** field (partially masked, e.g. `86518f6a-86b2-4e7a-8b83-4a7926f...`). Click into that field to reveal/select the full value, then copy and store it somewhere safe — this is the only time it's shown in full.

8. **Determine your HEC endpoint.** There is no page in the Splunk Cloud web console (not the token page, not Global Settings) that prints the full URI, and the hostname pattern varies by stack — don't assume a prefix like `http-inputs-` or `input-` exists for your stack. Confirm it directly:

   a. Try resolving the candidate prefixes first:
      ```bash
      nslookup http-inputs-<your-stack-name>.splunkcloud.com
      nslookup input-<your-stack-name>.splunkcloud.com
      nslookup <your-stack-name>.splunkcloud.com
      ```
      Only one of these is likely to resolve — for some stacks (as in this lab), **neither ingest-prefix variant exists**, and HEC simply runs on port 8088 of your main stack hostname (the same one you log into Splunk Cloud Web with).

   b. Once you know which hostname resolves, confirm HEC is actually listening there with the built-in health check (no token needed):
      ```bash
      curl -v https://<resolved-hostname>:8088/services/collector/health
      ```
      A response like `{"text":"HEC is healthy","code":17}` confirms the host/port are correct.

   c. **If instead you get `curl: (60) SSL certificate problem: self-signed certificate in certificate chain`**, the host/port are correct, but something between your Linux box and Splunk Cloud is intercepting and re-signing the TLS connection — genuine Splunk Cloud certs are always publicly trusted (e.g. DigiCert), never self-signed. This is typically a corporate proxy/firewall doing SSL inspection, or endpoint security software on the host. Identify it:
      ```bash
      openssl s_client -connect <resolved-hostname>:8088 -showcerts </dev/null 2>/dev/null | openssl x509 -noout -issuer -subject
      ```
      Check the **issuer** line — if it names your company, a security vendor (e.g. Zscaler, Palo Alto), or anything other than a known public CA, that's your interceptor. Fix it by adding your organization's root CA to the system trust store:
      ```bash
      sudo cp your-corp-root-ca.crt /etc/pki/ca-trust/source/anchors/
      sudo update-ca-trust
      ```
      As a one-time diagnostic only (not for real use), you can bypass verification with `curl -k` to confirm the endpoint itself is otherwise fine while you sort out the trust chain — but don't leave `-k` in any script or long-term command you keep, since it disables certificate validation entirely.

   Once resolved, your event endpoint is:
   ```
   https://<resolved-hostname>:8088/services/collector/event
   ```

This workshop's main path is the Universal Forwarder (Part 3), since it's the more common production pattern for tailing existing log files — but Part 4 shows how to validate with a manual HEC test too.

---

## Part 3 — Install and Configure the Universal Forwarder on Linux (Manual)

All steps below are run directly in a terminal on the Linux host, one command at a time — nothing scripted or automated.

### Step 3.1 — Check Prerequisites

```bash
# Confirm architecture
uname -m
# Confirm OS/version
cat /etc/os-release
```

You should see `NAME="Rocky Linux"` and an architecture of `x86_64` (or `aarch64` on ARM instances). Rocky Linux is RPM-based (same family as RHEL/CentOS), so you'll use the `.rpm` Universal Forwarder package and `dnf`/`rpm` for all installs in this lab.

### Step 3.2 — Download the Universal Forwarder Package

1. From a browser (on the Linux host itself, or download elsewhere and transfer with `scp`), go to:
   `https://www.splunk.com/en_us/download/universal-forwarder.html`
2. Select your OS and architecture, and download the package. You'll need a free Splunk.com account to access the download (separate from your Splunk Cloud trial login) — sign up if prompted.
3. If downloading directly on the Linux host via `wget`, copy the exact link Splunk's download page gives you after selecting your OS (the version number changes frequently, so don't hardcode an old URL) — right-click **Download via command line** on the download page to get the current `wget` command, or copy the link address.

Example pattern (yours will differ by current version):

```bash
wget -O splunkforwarder.rpm "https://download.splunk.com/products/universalforwarder/releases/<version>/linux/splunkforwarder-<version>-linux-x86_64.rpm"
```

### Step 3.3 — Install the Package

```bash
sudo rpm -ivh splunkforwarder.rpm
```

Verify the install location exists:

```bash
ls /opt/splunkforwarder
```

You should see directories like `bin`, `etc`, `var`.

### Step 3.4 — Start the Forwarder for the First Time

```bash
sudo /opt/splunkforwarder/bin/splunk start --accept-license
```

You will be prompted:
- Create an administrator username (e.g., `admin`)
- Create a password for that account

This login is **local to the forwarder's own management interface** (port 8089) — it is separate and unrelated to your Splunk Cloud web login from Part 1. Record it somewhere, you'll need it in the next steps.

Wait for the output to confirm:

```
Splunk> ...
The Splunk web interface is at http://<hostname>:8000
```

(The UF doesn't actually run a full web UI by default, but you should see a "Splunk started" type confirmation without errors.)

### Step 3.5 — Enable Boot-Start

So the forwarder restarts automatically if the Linux host reboots:

```bash
sudo /opt/splunkforwarder/bin/splunk enable boot-start
```

Confirm it created a service:

```bash
sudo systemctl status SplunkForwarder
```

You should see it listed as a systemd service (`enabled`), even if not currently `active` (it may show active since you just started it).

### Step 3.6 — Transfer the Credentials Package to the Linux Host

If you downloaded the `splunkclouduf.spl` file (Step 2.3) on a different machine (e.g., your laptop), copy it to the Linux host now:

```bash
scp /local/path/to/splunkclouduf.spl <user>@<linux-host>:/tmp/
```

If you downloaded it directly on the Linux host already, just confirm its location:

```bash
ls -l /tmp/splunkclouduf.spl
```

### Step 3.7 — Install the Credentials Package as a Forwarder App

```bash
sudo /opt/splunkforwarder/bin/splunk install app /tmp/splunkclouduf.spl \
  -auth admin:<the-uf-password-you-set-in-step-3.4>
```

Expected output confirms the app installed successfully, something like:

```
App '/tmp/splunkclouduf.spl' installed
```

### Step 3.8 — Verify the Cloud Connection Config Landed Correctly

```bash
cat /opt/splunkforwarder/etc/apps/*cloud*/default/outputs.conf
```

You should see a stanza referencing your stack's forwarder input endpoint from Step 2.4, e.g.:

```ini
[tcpout:splunkcloud]
server = inputs<your-stack-id>.splunkcloud.com:9997
sslCertPath = $SPLUNK_HOME/etc/apps/.../cert.pem
sslPassword = ...
```

Confirm the `server =` value matches what you noted in Step 2.4. If it doesn't match, re-download the credentials package — you may have grabbed one for the wrong stack.

### Step 3.9 — Restart the Forwarder to Apply the Cloud Config

```bash
sudo /opt/splunkforwarder/bin/splunk restart
```

### Step 3.10 — Verify Forwarder Connectivity to Splunk Cloud

```bash
/opt/splunkforwarder/bin/splunk list forward-server -auth admin:<uf-password>
```

Look for output like:

```
Active forwards:
	inputs<your-stack-id>.splunkcloud.com:9997
Configured but inactive forwards:
	None
```

- **Active forwards** = success, the UF has an authenticated connection to Splunk Cloud.
- If it shows under **Configured but inactive forwards** instead, the most common causes are:
  - Your Linux host's IP wasn't correctly added to the allow list (recheck Step 2.2)
  - A firewall/security group on the Linux host or its network is blocking outbound port `9997`
  - The credentials package doesn't match this stack (redo Step 2.3/3.7)

To check outbound connectivity directly:

```bash
telnet inputs<your-stack-id>.splunkcloud.com 9997
```

or, if `telnet` isn't installed:

```bash
sudo yum install -y nmap-ncat   # RHEL/CentOS
# or
sudo apt install -y ncat        # Ubuntu/Debian

nc -zv inputs<your-stack-id>.splunkcloud.com 9997
```

A successful connection confirms the network path is open; a hang or refusal points back to allow-list or firewall configuration.

---

## Part 4 — Install Apache (httpd) on Rocky Linux and Forward Its Logs

Instead of (or in addition to) the hand-written test file in Part 4 above, this section uses a **real application** — Apache HTTP Server — as the log source, since it's a realistic example of "install an app, point the forwarder at its logs." Rocky Linux ships Apache as the `httpd` package via `dnf`.

### Step 4.1 — Install httpd

```bash
sudo dnf install -y httpd
```

Confirm it installed:

```bash
httpd -v
```

### Step 4.2 — Start and Enable httpd

```bash
sudo systemctl start httpd
sudo systemctl enable httpd
sudo systemctl status httpd
```

Confirm `status` shows `active (running)`.

### Step 4.3 — Open the Firewall Port (firewalld, Rocky's default)

```bash
sudo firewall-cmd --permanent --add-service=http
sudo firewall-cmd --reload
sudo firewall-cmd --list-services
```

Confirm `http` appears in the output.

### Step 4.4 — Generate Some Traffic Against Apache

From the same host (or another machine that can reach it):

```bash
curl http://localhost/
curl http://localhost/nonexistent-page
curl http://localhost/another-missing-path
```

The first request returns Apache's default **200** test page; the other two generate **404** responses — useful variety for testing error-rate searches later.

### Step 4.5 — Locate Apache's Log Files

Rocky Linux's default Apache log locations:

```bash
ls -l /var/log/httpd/
```

You should see:

```
access_log   ← every request Apache serves (method, path, status, response size)
error_log    ← Apache startup/runtime/module errors
```

Inspect a few lines to see the raw format:

```bash
sudo tail -5 /var/log/httpd/access_log
sudo tail -5 /var/log/httpd/error_log
```

`access_log` is in **Apache Combined Log Format** by default — this is a well-known format Splunk already recognizes with a built-in sourcetype (`access_combined`), so you won't need to write custom parsing rules for it like you did for the JSON example.

### Step 4.6 — Grant the Forwarder Permission to Read the Logs

By default `/var/log/httpd/*` is owned by `root`, and Rocky Linux's SELinux policy also restricts access — the Universal Forwarder needs to be able to read these files.

Check current ownership/permissions:

```bash
ls -l /var/log/httpd/access_log
```

If the Universal Forwarder is running as `root` (the default after `splunk start` run via `sudo`), file ownership usually isn't a blocker. If you configured the UF to run as a **non-root user** (a common production hardening step), add that user to a group with read access, or adjust an ACL:

```bash
# Example only if running the UF as a dedicated non-root user, e.g. "splunkfwd"
sudo setfacl -m u:splunkfwd:rx /var/log/httpd
sudo setfacl -m u:splunkfwd:r /var/log/httpd/access_log
sudo setfacl -m u:splunkfwd:r /var/log/httpd/error_log
```

If SELinux is enforcing (check with `getenforce`), confirm it isn't blocking reads:

```bash
getenforce
sudo ausearch -m avc -ts recent | grep splunk
```

If you see AVC denials referencing the Splunk process, this needs an SELinux policy adjustment (outside the scope of this lab) — for a lab environment running the UF as `root`, this typically isn't an issue.

### Step 4.7 — Create a New Monitor Input for httpd Logs

Create a separate app directory for this input (keeps it cleanly separated from the earlier `api_logs_input` app):

```bash
sudo mkdir -p /opt/splunkforwarder/etc/apps/httpd_logs_input/local
```

```bash
sudo vi /opt/splunkforwarder/etc/apps/httpd_logs_input/local/inputs.conf
```

Enter:

```ini
[monitor:///var/log/httpd/access_log]
disabled = false
index = api_logs
sourcetype = access_combined

[monitor:///var/log/httpd/error_log]
disabled = false
index = api_logs
sourcetype = apache_error
```

- `access_combined` and `apache_error` are **built-in Splunk sourcetypes** — no custom `props.conf` needed for basic parsing; Splunk already knows how to extract fields like `clientip`, `status`, `method`, `uri_path`, `bytes` from combined-format access logs.

Save and exit.

### Step 4.8 — Restart the Forwarder to Pick Up the New Inputs

```bash
sudo /opt/splunkforwarder/bin/splunk restart
```

### Step 4.9 — Confirm Both httpd Inputs Are Being Monitored

```bash
sudo /opt/splunkforwarder/bin/splunk list monitor -auth admin:<uf-password>
```

Confirm both `/var/log/httpd/access_log` and `/var/log/httpd/error_log` appear.

### Step 4.10 — Generate More Traffic and Search in Splunk Cloud

Back on the Linux host:

```bash
curl http://localhost/
curl http://localhost/api/test
curl -I http://localhost/
```

Then in Splunk Cloud **Search & Reporting**, with time range set to **Last 15 minutes**:

```spl
index=api_logs sourcetype=access_combined
```

You should see the requests you just generated, with `clientip`, `status`, `method`, `uri_path` already broken out in the field sidebar (from the built-in `access_combined` field extractions).

Try a quick status breakdown, same pattern as Section 5.1 in the main workshop:

```spl
index=api_logs sourcetype=access_combined
| stats count by status
```

You should see a mix of `200` and `404` from your earlier `curl` calls.

### Step 4.11 — Check the Error Log Too

```spl
index=api_logs sourcetype=apache_error
```

You should see Apache's own startup/module log lines from Step 4.2's `systemctl start httpd`.

---

## Part 4a — Hand-Written JSON Log Input (Alternate/Additional Source)

### Step 4.1 — Create a Test Log Directory and File

```bash
sudo mkdir -p /var/log/api
sudo touch /var/log/api/app.log
sudo chmod 644 /var/log/api/app.log
```

### Step 4.2 — Write a Few Sample Log Lines by Hand

```bash
sudo tee -a /var/log/api/app.log > /dev/null <<'EOF'
{"timestamp":"2026-08-19T10:15:32Z","service":"checkout-api","method":"POST","endpoint":"/v1/orders","status":201,"latency_ms":142,"request_id":"req-98213","trace_id":"trace-7c1a"}
{"timestamp":"2026-08-19T10:15:41Z","service":"payment-service","method":"POST","endpoint":"/v1/charge","status":500,"latency_ms":1820,"request_id":"req-98214","trace_id":"trace-7c1a"}
{"timestamp":"2026-08-19T10:16:02Z","service":"inventory-service","method":"GET","endpoint":"/v1/stock","status":200,"latency_ms":88,"request_id":"req-98215","trace_id":"trace-9d2b"}
EOF
```

(This is a manual, one-time write for the lab — in real usage your application would append these lines itself as it runs.)

### Step 4.3 — Create the Monitor Input App Directory

```bash
sudo mkdir -p /opt/splunkforwarder/etc/apps/api_logs_input/local
```

### Step 4.4 — Create `inputs.conf` by Hand

```bash
sudo vi /opt/splunkforwarder/etc/apps/api_logs_input/local/inputs.conf
```

Enter the following content, then save and exit (`:wq` in vi):

```ini
[monitor:///var/log/api/app.log]
disabled = false
index = api_logs
sourcetype = api_json
```

### Step 4.5 — (Optional but Recommended) Create `props.conf` for Correct JSON Parsing

```bash
sudo vi /opt/splunkforwarder/etc/apps/api_logs_input/local/props.conf
```

```ini
[api_json]
KV_MODE = json
TIME_PREFIX = "timestamp":"
TIME_FORMAT = %Y-%m-%dT%H:%M:%SZ
SHOULD_LINEMERGE = false
LINE_BREAKER = ([\r\n]+)
```

> Note: on a pure Universal Forwarder, `props.conf`/`transforms.conf` for **parsing** (as opposed to input monitoring) technically take effect at the **indexing tier**, which in Splunk Cloud is managed for you. For a lab, it's fine to keep this local file — but for a durable setup, this parsing configuration should instead be added as a **Splunk Cloud "indexer-side" app**, uploaded via **Settings → Apps → Install App from File** in Splunk Cloud Web (self-service app install), or through the ACS API, so the managed indexers apply it.

### Step 4.6 — Restart the Forwarder to Pick Up the New Input

```bash
sudo /opt/splunkforwarder/bin/splunk restart
```

### Step 4.7 — Confirm the Forwarder Sees the File Locally

```bash
sudo /opt/splunkforwarder/bin/splunk list monitor -auth admin:<uf-password>
```

You should see `/var/log/api/app.log` listed as an active monitored input.

### Step 4.8 — Search for the Events in Splunk Cloud

1. Go back to your Splunk Cloud stack in the browser, log in (Part 1 credentials).
2. Open **Search & Reporting**.
3. Set the time range picker (top right of the search bar) to **Last 60 minutes**.
4. Run:
   ```spl
   index=api_logs sourcetype=api_json
   ```
5. Click **Search**.

You should see the three events you wrote by hand in Step 4.2, with fields like `service`, `status`, `latency_ms`, `trace_id` already broken out in the left-hand field sidebar (confirming `KV_MODE=json` parsing worked).

> If nothing appears after a minute or two, re-check: allow list (2.2), forwarder connectivity (`list forward-server`, Step 3.10), and that the file path in `inputs.conf` exactly matches the file you wrote to.

### Step 4.9 — Add a Line Manually and Confirm It Arrives

To prove the monitor is live-tailing (not just a one-time read):

```bash
sudo tee -a /var/log/api/app.log > /dev/null <<'EOF'
{"timestamp":"2026-08-19T10:20:00Z","service":"user-service","method":"GET","endpoint":"/v1/profile","status":200,"latency_ms":55,"request_id":"req-98216","trace_id":"trace-4f11"}
EOF
```

Wait ~10–15 seconds, then re-run the same search in Splunk Cloud (or click the refresh/re-run search button). Confirm the fourth event now appears.

---

## Part 5 — (Optional) Manually Validate the HEC Path Too

If you created a HEC token in Step 2.5, confirm that path also works, entirely by hand from the terminal. Use the trial-stack endpoint pattern from Step 2.5.9 (`http-inputs-<stack>.splunkcloud.com:8088` on a free trial), and ideally run the `/services/collector/health` check from that step first if you haven't already:

```bash
curl https://http-inputs-<your-stack-name>.splunkcloud.com:8088/services/collector/event \
  -H "Authorization: Splunk <HEC_TOKEN>" \
  -d '{"event": {"timestamp":"2026-08-19T10:25:00Z","service":"checkout-api","method":"POST","endpoint":"/v1/orders","status":503,"latency_ms":2210,"request_id":"req-98217","trace_id":"trace-4f11"}, "sourcetype":"api_json","index":"api_logs"}'
```

Expected response:

```json
{"text":"Success","code":0}
```

Then in Splunk Cloud search:

```spl
index=api_logs sourcetype=api_json request_id="req-98217"
```

Confirm the event shows up. You now have **two independently verified ingestion paths** landing in the same index.

---

## Lab Completion Checklist

- [ ] Signed up for Splunk Cloud free trial and logged into the stack
- [ ] Created the `api_logs` index manually via Settings → Indexes
- [ ] Added the Linux host's IP to the Splunk Cloud IP allow list
- [ ] Downloaded the Universal Forwarder credentials package from Splunk Cloud Web
- [ ] Installed the Universal Forwarder package on the Rocky Linux host
- [ ] Started the forwarder and set a local admin password
- [ ] Enabled boot-start
- [ ] Installed the credentials package as an app on the forwarder
- [ ] Verified `outputs.conf` points at the correct stack endpoint
- [ ] Confirmed `splunk list forward-server` shows an **active** forward
- [ ] Installed `httpd` via `dnf`, started/enabled it, opened the firewall port
- [ ] Generated test traffic with `curl` and confirmed logs land in `/var/log/httpd/`
- [ ] Wrote an `inputs.conf` monitoring `access_log`/`error_log` with `access_combined`/`apache_error` sourcetypes
- [ ] Searched `index=api_logs sourcetype=access_combined` and saw real Apache events with auto-extracted fields
- [ ] Manually created `/var/log/api/app.log` and wrote sample JSON lines
- [ ] Manually wrote `inputs.conf` (and `props.conf`) to monitor that file
- [ ] Searched `index=api_logs sourcetype=api_json` in Splunk Cloud and saw the events
- [ ] Appended a new line and confirmed live-tail behavior
- [ ] (Optional) Sent and confirmed a manual HEC test event

---

## Common Pitfalls Reference

| Symptom | Likely Cause | Fix |
|---|---|---|
| `splunk list forward-server` shows "Configured but inactive" | IP not on allow list, or firewall blocking 9997 | Recheck Step 2.2; test with `nc -zv` |
| Events never appear in search | Wrong index/sourcetype in `inputs.conf`, or wrong file path | Re-check `inputs.conf` matches the exact file path being written to |
| Fields not auto-extracted (only `_raw` shown) | `props.conf` missing/wrong, or not applied at the indexing tier | Re-check `KV_MODE=json`; for durable setups, push parsing config as a Splunk Cloud app rather than a UF-local file |
| `splunk install app` fails with an auth error | Wrong local UF admin password | Reset via `splunk edit user admin -password <new> -auth admin:<old>` |
| HEC returns 403 | Token disabled, wrong index/sourcetype restriction on the token, or IP not allow-listed for HEC | Recheck Step 2.5 and 2.2 |
| `curl: could not connect` / connection refused to HEC | Wrong host pattern (missing `http-inputs-` prefix) or wrong port for your stack type | Try the `/services/collector/health` check from Step 2.5.9 first; trial = `http-inputs-<stack>...:8088`, paid AWS = `...:443`, paid GCP = `http-inputs.<stack>...:443` |
| Trial license blocks ingestion | Daily indexing volume cap hit | Check **Settings → License Usage**; wait for daily reset or reduce test data volume |

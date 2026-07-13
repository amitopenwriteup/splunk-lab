# Lab: Splunk RUM (Agent-Based / npm) — Apache App on Rocky Linux

**Objective:** Instrument the Apache app using the `@splunk/otel-web` npm package (bundled agent) instead of the CDN script tag, and validate in Splunk Observability Cloud.

**Assumes:** Apache is installed and serving `/var/www/html/index.html` (Exercise 1 of the Apache lab). Node.js and npm are available on the host.

**Estimated time:** 20–30 minutes

---

## Prerequisites

```bash
node -v
npm -v
```

If Node isn't installed:

```bash
sudo dnf install -y nodejs
```

Generate a RUM access token in Splunk Observability Cloud first (**Settings → Access Tokens → New Token → RUM Token**) and note your **realm** (e.g. `us0`, `us1`, `eu0`).

---

## Exercise 1 — Set up a small build project

The npm-based agent needs to be bundled — it isn't loaded as a loose script tag. Create a build folder next to the Apache docroot:

```bash
sudo mkdir -p /opt/rum-build
cd /opt/rum-build
sudo npm init -y
sudo npm install @splunk/otel-web
sudo npm install --save-dev esbuild
```

---

## Exercise 2 — Create the instrumentation file

```bash
sudo tee /opt/rum-build/splunk-instrumentation.js > /dev/null <<'EOF'
import { SplunkRum } from '@splunk/otel-web';

SplunkRum.init({
  realm: '<your-realm>',
  rumAccessToken: '<your-rum-token>',
  applicationName: 'apache-lab-app',
  deploymentEnvironment: 'lab',
});
EOF
```

Replace `<your-realm>` and `<your-rum-token>` with your actual values.

---

## Exercise 3 — Bundle it and drop the output into Apache's docroot

```bash
cd /opt/rum-build
sudo npx esbuild splunk-instrumentation.js --bundle --outfile=/var/www/html/splunk-rum-bundle.js
```

### Validate

```bash
ls -lh /var/www/html/splunk-rum-bundle.js
curl -I http://localhost/splunk-rum-bundle.js
```

**Expected:** the file exists and Apache serves it with HTTP `200`.

---

## Exercise 4 — Reference the bundle from the page

```bash
sudo vi /var/www/html/index.html
```

Add this as the **first script** inside `<head>`, before any other scripts:

```html
<head>
  <script src="/splunk-rum-bundle.js"></script>
  <!-- rest of existing head content -->
</head>
```

No Apache restart needed — static files serve immediately.

---

## Exercise 5 — Generate traffic and validate

Open the page in an actual browser (not `curl` — RUM needs a real JS engine to run):

```
http://<host>/
```

Click around the page a few times to generate interaction spans.

### Validate in the UI
**Digital Experience → Real User Monitoring → Overview** → filter **Source: Browser** → confirm `apache-lab-app` appears with recent sessions.

---

## Rebuilding after changes

Any time you edit `splunk-instrumentation.js` (e.g. to add `globalAttributes` or adjust sampling), re-run the bundle step:

```bash
cd /opt/rum-build
sudo npx esbuild splunk-instrumentation.js --bundle --outfile=/var/www/html/splunk-rum-bundle.js
```

The npm-based approach means every config change goes through this rebuild step — unlike the CDN script tag, which you can edit directly in the HTML.

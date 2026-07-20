# Lab: Set Up and Test an SSL Monitor in Splunk Synthetics

## Goal

By the end of this lab you'll have:
1. A self-signed HTTPS endpoint on your private-IP server to point a test at.
2. A working **SSL test** in Splunk Synthetics (the "Create SSL test" screen) running from a **private location** against that server.
3. Validation rules configured so the test actually fails when something is wrong — not just when the site is down.
4. Confidence that the alert fires correctly, because you'll have triggered it on purpose.

Estimated time: 20–30 minutes.

---

## Part 1 — Set up the test endpoint

```bash
# Generate a self-signed cert valid for 3 days (so you can test "near expiry" too)
mkdir ssl-lab && cd ssl-lab
openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout key.pem -out cert.pem -days 3 \
  -subj "/CN=ssl-lab.local"

# Serve it over HTTPS on port 8443
# (plain `python3 -m http.server` doesn't do TLS — use openssl's own TLS listener instead)
openssl s_server -accept 8443 -cert cert.pem -key key.pem -www &
```

Verify it's actually up and serving the right cert before moving on:

```bash
curl -vk https://localhost:8443/ 2>&1 | grep -A2 "subject:"
# should show: CN=ssl-lab.local
```

`ACCEPT` in the `s_server` log output just means it's listening and waiting for a connection — that's expected, not an error.

**If you get `OSError: [Errno 98] Address already in use`** when starting the listener, something is already bound to port 8443 (commonly a leftover `http.server` or a previous `s_server` process that wasn't stopped). Free the port first:

```bash
sudo lsof -i :8443          # find what's holding the port
kill <pid>                  # or: pkill -f http.server; pkill -f 's_server'
```

Then re-run the `openssl s_server` command above.

---

## Part 2 — Set up a private location

**Your server is on a private IP**, so the public AWS-region runners (Montreal, N. Virginia, N. California, Oregon — the ones in your screenshot) cannot reach it; they only see the public internet. To test this endpoint you need a Splunk Observability Cloud **private location**: an agent that runs inside your own network and executes the test from there instead of from AWS.

1. In Splunk Observability Cloud, go to **Synthetics → Private Locations** (or **Settings → Synthetics → Private Locations**, depending on your version) and click **Create private location**. Give it a name, e.g. `ssl-lab-private`.
2. Follow the setup instructions the UI gives you for installing the private location agent on a host with network access to your `ssl-lab` server. The exact install steps vary by Splunk Observability Cloud version — the **Create private location** screen will show the current instructions and any credentials/token needed for your org.
3. Wait for the location to show **Connected** / a green status in the Private Locations list before continuing — an agent that hasn't checked in yet will just make your test hang or report no data, which looks identical to a network problem.
4. Confirm the agent host can actually reach your `ssl-lab` server on its private IP:
   ```bash
   curl -vk https://<ssl-lab-private-ip>:8443/ 2>&1 | grep -A2 "subject:"
   ```
   Run this *from the agent host*, not your laptop — that's the network path the real test will use.

### Verifying a Docker-based agent

If you installed the private location agent as a Docker container, confirm it's actually working before moving on:

**Check the container is up and healthy:**
```bash
docker ps --filter "name=synthetics"
docker logs <container_name> --tail 50
```
Look for a log line confirming it registered/connected to Splunk Observability Cloud — the exact wording varies by version, but a repeating heartbeat/poll message is normal; a repeating auth or connection error is not.

**Confirm it shows "Connected" in the UI** — check **Synthetics → Private Locations** for the status next to the location you created. If Docker looks fine locally but the UI still shows disconnected, it's usually one of:
- Wrong or expired access token passed into the container
- Container can't reach Splunk's ingest endpoints outward (check outbound firewall/proxy rules on the Docker host)

**Confirm the container can reach your `ssl-lab` server** — run this *from inside the container* (or from the Docker host if it uses host networking), not from your laptop:
```bash
docker exec -it <container_name> curl -vk https://<ssl-lab-private-ip>:8443/ 2>&1 | grep -A2 "subject:"
```
This is the actual network path the SSL test will use, so if this fails, the test will fail with a connection error regardless of how correct your validation rules are.

Once you see **Connected** in the UI and this `curl` returns the `CN=ssl-lab.local` subject line, you're ready for Part 3.

---

## Part 3 — Create the SSL test

Using the screen you have open (Synthetics → Create SSL test → Simple):

1. **Name**: `ssl-lab-private-server`
2. **Hostname**: the private IP of your `ssl-lab` box, e.g. `10.x.x.x` (not `localhost` — the private location agent is a different host than the one running `s_server`, unless you deliberately ran both on the same machine)
3. **Port**: `8443`
4. **Custom properties**: skip for now — these are just tags for filtering, not required for the test to function.
5. **Validation** → click **Add validation**. This is the part that actually matters — an SSL test with no validation rules only checks "did the TLS handshake succeed," not "is the cert actually healthy." Add:
   - **Days until expiration** → greater than `1` — remember this cert was generated with `-days 3`, so set the threshold low enough to actually pass against your short-lived lab cert. You can lower the cert's `-days` value later to deliberately trip this rule.
   - **Common name / SAN matches hostname** → expect this to fail: the cert's CN is `ssl-lab.local` but you're hitting it by IP address, so CN/SAN won't match. That's worth seeing fail once so you understand why the check matters — you can reissue the cert with the IP as a SAN later if you want it to pass instead.
   - **Certificate is trusted** (chains to a trusted root) → expect this to fail too — this is a self-signed cert, so no trust chain exists. That's the expected result for this target, not a bug.
6. **Locations**: remove the four AWS regions and select your **`ssl-lab-private`** private location instead. This is the step people miss most often — if the public regions are still selected, the test will just fail with a connection/timeout error that looks identical to a real network problem, instead of exercising the cert validation logic you actually care about.
7. **Frequency**: for a lab, set this to the shortest interval offered (often 1 or 5 minutes) so you don't wait long to see results. In production you'd typically use 15–60 minutes for a cert check, since expiry doesn't change minute to minute.
8. Click **Create**.

---

## Part 4 — Run it and read the results

1. Go back to the Synthetics test list and either wait for the first scheduled run or use **Run now** / **Test** if the UI offers it for an immediate check.
2. Open the test's detail view and check:
   - **Overall status** (pass/fail)
   - **Which specific validation failed** — this is the important part. Expect: expiration check **passes** (if you set the threshold low per Part 3 step 5), hostname-match check **fails** (CN is `ssl-lab.local`, you're hitting it by IP), trust-chain check **fails** (self-signed).
3. If instead the whole test errors out with a connection timeout rather than reporting per-check pass/fail, that's a network-reachability problem, not a cert problem — go back and confirm the private location agent shows **Connected**, and re-run the `curl` reachability check from Part 2 step 4.

If a validation you expected to fail instead passes, the most common cause is a validation rule that wasn't actually saved/enabled — double check Part 3 step 5 rather than assuming the target is fine.

---

## Part 5 — Wire up alerting (optional but recommended)

A monitor nobody gets notified from is just a dashboard nobody looks at.

1. From the test detail page, look for **Alert rules** / **Detectors** (naming varies by Splunk Observability Cloud version).
2. Create a rule: trigger on **test status = Fail** or on the specific **"days until expiration" < threshold** signal, for at least 1 consecutive run (avoids alerting on a single transient network blip).
3. Point it at a real notification channel (email, Slack, PagerDuty, etc.) so you can confirm the alert actually reaches you — fire it once (e.g. by lowering the expiration cert's `-days` value until it trips) and check delivery.

---

## Part 6 — Clean up

Once you've confirmed everything works:

- Delete the lab test (`ssl-lab-private-server`) or lower its frequency.
- Kill the background `s_server` process:
  ```bash
  kill %1   # or: pkill -f 's_server'
  ```
- If you spun up a private location just for this lab, remove it from **Synthetics → Private Locations** in the UI, and stop/remove the agent process on the host where you installed it so it doesn't sit around consuming a license seat / connection slot.
- Keep this test's structure (private-IP hostname + the three validation rules + private-location selection) as your template for the real internal certificates you actually need to monitor.

---

## What you should walk away knowing

- An SSL/TLS synthetic test with **no validation rules** only proves the handshake works — it will not warn you before a cert expires.
- The three checks that matter most for cert monitoring: **expiration window**, **hostname match**, **trust chain**. Set all three, not just expiry.
- Testing a private-IP endpoint requires a **private location** — public AWS-region runners can never reach it, and a misconfigured location selection shows up as a generic connection failure that looks like a network outage rather than a cert problem.
- A self-signed cert tested by IP will legitimately fail hostname-match and trust-chain checks — that's correct behavior, not a bug in the test.

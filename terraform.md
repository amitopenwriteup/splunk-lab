# Workshop: Monitoring as Code with the Splunk Observability Cloud Terraform Provider

**Based on:** Splunk's announcement of its official Terraform provider for Splunk Infrastructure Monitoring (formerly SignalFx)
**Level:** Beginner–Intermediate
**Duration:** ~60–90 minutes
**Goal:** Learn why "monitoring as code" matters, then use Terraform to create, update, and manage a Splunk Observability detector from scratch.

---

## Workshop Overview

Splunk Infrastructure Monitoring's Terraform provider became an officially supported HashiCorp provider, meaning you can reference it directly in your Terraform configuration and run `terraform init` — no more manually compiling or distributing a community-built binary. This workshop walks through the history, the reasoning behind managing monitoring as code, and a hands-on exercise building and modifying a real detector.

### What you'll learn
1. What "monitoring as code" means and why teams adopt it
2. When to use Terraform vs. the Splunk Observability Cloud UI
3. How to install and configure the provider
4. How to create a detector with Terraform
5. How to preview, apply, and modify infrastructure changes safely
6. Where to go next

### Prerequisites
- A Splunk Observability Cloud (Infrastructure Monitoring) account and an **API access token**
- [Terraform CLI](https://developer.hashicorp.com/terraform/install) installed locally
- A text editor
- Basic command-line familiarity

---

## Module 1: Background — Why This Provider Exists

Before writing any code, it helps to understand the history:

- In 2016, engineers at Yelp built an unofficial Terraform provider for Splunk Infrastructure Monitoring (then called SignalFx), originally named "SignalForm."
- In 2018, Stripe forked and extended that work.
- Eventually, Splunk partnered directly with HashiCorp to publish a fully supported, reviewed, and tested official provider — removing the need for teams to self-host or manually build the plugin.

**Discussion prompt:** Has your team ever adopted a community tool that later became officially supported? What changed operationally when that happened (trust, maintenance burden, update cadence)?

---

## Module 2: Why "Monitoring as Code"?

Terraform is an infrastructure-as-code tool: you describe resources in configuration files, store those files in version control, and apply them consistently across environments. Since dashboards, alerts, and detectors are part of your infrastructure, they benefit from the same treatment:

- **Version history** — every change to an alert or dashboard has a Git commit and author
- **Collaboration** — anyone on the team can propose a change via pull request
- **Consistency** — the same detector definition can be deployed across projects or environments
- **Speed at scale** — large sets of monitoring assets can be created or updated in bulk

Terraform isn't the only option — some teams have used other automation approaches or written directly against the Infrastructure Monitoring API — but Terraform is the most common because most infrastructure teams already use it.

### When should you use Terraform vs. the UI?

| Use the UI when... | Use Terraform when... |
|---|---|
| You're iterating quickly on a new detector | Your org wants Git history for every alerting change |
| A single person owns the dashboard | You want pull-request review on alert changes |
| You want to use built-in features like mirrored dashboards | Alerts should live alongside application code in the same repo |

A common hybrid workflow: build and tune a detector in the UI first (fast iteration), then use `terraform import` or export the resulting configuration to bring it under version control once it's stable.

---

## Module 3: Set Up Your Environment

1. Create a new, empty working directory:
   ```bash
   mkdir terraform-observability-workshop
   cd terraform-observability-workshop
   ```

2. Retrieve an **API access token** from your Splunk Observability Cloud organization settings. Keep this secret — treat it like a password.

3. Confirm Terraform is installed:
   ```bash
   terraform -version
   ```

---

## Module 4: Configure the Provider

Create a file named `main.tf` and declare the provider:

```hcl
terraform {
  required_providers {
    signalfx = {
      source  = "splunk-terraform/signalfx"
      version = "~> 8.0"
    }
  }
}

provider "signalfx" {
  auth_token = var.signalfx_api_token
  # If your org uses SSO or a custom subdomain, set this too:
  # custom_app_url = "https://yourorg.signalfx.com"
}
```

Create a `variables.tf` file so your token isn't hard-coded into version control:

```hcl
variable "signalfx_api_token" {
  description = "Splunk Observability Cloud API access token"
  type        = string
  sensitive   = true
}
```

Set the token as an environment variable rather than committing it:

```bash
export TF_VAR_signalfx_api_token="XXXADDTOKENHERE"
```

> **Tip:** Always keep API tokens out of version control. Use environment variables, a secrets manager, or an encrypted `.tfvars` file excluded via `.gitignore`.

---

## Module 5: Create Your First Detector

Add a detector resource to `main.tf`. This example alerts when a service's request latency exceeds a threshold:

```hcl
resource "signalfx_detector" "checkout_latency" {
  name        = "Checkout latency is high"
  description = "Alerts when checkout service latency exceeds expectations"

  program_text = <<-EOF
    signal = data('checkout.latency_seconds').max()
    detect(when(signal > 2, '1m')).publish('Latency High')
  EOF

  rule {
    detect_label = "Latency High"
    description  = "Latency exceeded 2 seconds for the last minute"
    severity     = "Critical"
    # notifications = ["Team-ABC123"]  # Add a notification target here
  }
}
```

**Exercise:** Before running anything, read through the config and answer:
- What metric is being monitored?
- What condition triggers the alert?
- What severity is assigned?

---

## Module 6: Initialize, Plan, and Apply

### Step 1 — Initialize
```bash
terraform init
```
This downloads and installs the Splunk Infrastructure Monitoring provider plugin.

### Step 2 — Plan
```bash
terraform plan
```
Terraform shows an execution plan describing what it *would* do — no changes are made yet. Look for a `+ create` action on `signalfx_detector.checkout_latency`.

### Step 3 — Apply
```bash
terraform apply
```
Review the plan, type `yes` to confirm, and Terraform will create the detector via the API.

**Checkpoint:** Log in to Splunk Observability Cloud and confirm your new detector appears. Detectors created via API/Terraform may look slightly different in the UI than ones authored manually there — that's expected.

---

## Module 7: Make a Change Safely

Suppose your team tightens its SLA and wants to alert at 1 second instead of 2. Edit the `program_text` in `main.tf`:

```hcl
    detect(when(signal > 1, '1m')).publish('Latency High')
```

Run `terraform plan` again. Terraform will show a `~ change` (not a `+ create`), diffing the old and new `program_text`. This is the safety net Terraform gives you: you always see what will change before it happens.

Run `terraform apply` and confirm. Your detector updates in place — no duplicate resources, no manual UI edits.

**Exercise:** Try changing the `severity` from `"Critical"` to `"Warning"` and run `terraform plan` again. Notice how Terraform tracks every field individually.

---

## Module 8: Clean Up (Optional)

To remove the resources you created during this workshop:

```bash
terraform destroy
```

Review the plan carefully — `destroy` is irreversible for anything not already tracked elsewhere.

---

## Module 9: Where to Go Further

- Explore other resource types the provider supports: dashboards, dashboard groups, notification integrations, and organization settings
- Try `terraform import` to bring an existing UI-authored detector under Terraform management
- Set up a CI/CD pipeline that runs `terraform plan` on pull requests and `terraform apply` on merge to main
- Store your `.tf` files in the same repository as the service they monitor, so alerts evolve alongside the code

---

## Wrap-Up Discussion Questions

1. Where would "monitoring as code" fit into your team's current workflow?
2. What monitoring assets (dashboards, detectors, integrations) would benefit most from version control and PR review?
3. What's your plan for handling secrets like API tokens in your Terraform pipeline?

---

*Workshop content adapted and expanded from Splunk's blog post on the release of their official Terraform provider (July 2020). For the authoritative, up-to-date provider documentation, always check the official Terraform Registry page for the `signalfx` provider.*

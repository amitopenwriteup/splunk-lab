# Splunk OTel Collector Installation on Kubernetes — Terraform + Helm

## 1. Prerequisites

- Terraform >= 1.5
- A working `kubectl` context pointing at your target cluster
- Helm 3 (not strictly required locally since Terraform's `helm` provider talks to Helm internally, but useful for debugging)
- A Splunk Observability Cloud **access token** and **realm**

## 2. Providers

```hcl
tee providers.tf > /dev/null <<'EOF'
terraform {
  required_version = ">= 1.5"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}
EOF
```

If Terraform is running inside the cluster (e.g. a CI runner with a service account), swap `config_path` for in-cluster auth, or for EKS/GKE/AKS use the respective data source (`aws_eks_cluster`, `google_container_cluster`, etc.) to populate `host`, `cluster_ca_certificate`, and `token` instead of a kubeconfig file.

## 3. Namespace

```hcl
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
  }
}
```

## 4. Helm release for the collector

```hcl
resource "helm_release" "splunk_otel_collector" {
  name       = "splunk-otel-collector"
  repository = "https://signalfx.github.io/splunk-otel-collector-chart"
  chart      = "splunk-otel-collector"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "0.104.0" # pin a chart version deliberately; don't float on "latest"

  values = [
    yamlencode({
      clusterName = var.cluster_name
      environment = var.environment

      splunkObservability = {
        accessToken = var.splunk_access_token
        realm       = var.splunk_realm
      }

      # Optional: tune for a managed distribution
      # distribution  = "eks"
      # cloudProvider = "aws"
    })
  ]
}
```

## 5. Variables

```hcl
variable "cluster_name" {
  type        = string
  description = "Name reported to Splunk Observability Cloud"
}

variable "environment" {
  type        = string
  default     = "prod"
}

variable "splunk_realm" {
  type        = string
  default     = "us1"
}

variable "splunk_access_token" {
  type        = string
  description = "Splunk Observability Cloud org access token"
  sensitive   = true
}
```

## 6. Do you need to put the token in the `.tf` file?

**No — and you shouldn't.** Options, in order of preference:

| Approach | How | Notes |
|---|---|---|
| **Secrets manager** | Pull via a data source (`aws_secretsmanager_secret_version`, `azurerm_key_vault_secret`, Vault provider, etc.) and pass the result into `var.splunk_access_token` | Best for production; token never touches disk or state in plaintext view |
| **Environment variable** | `export TF_VAR_splunk_access_token="xxxx"` before `terraform apply` | Simple for CI pipelines; keep it in a masked/secret CI variable |
| **Kubernetes Secret + `valuesFrom`** | Create the token as a `kubernetes_secret` resource, reference it via chart's secret-based values (chart supports `splunkObservability.accessTokenSecret`) instead of a raw value | Avoids the token appearing in Helm values at all |
| **`.tfvars` file** | Only if the file is gitignored and access-controlled | Least preferred — easy to leak by accident |

Regardless of method, the token **will** still appear in Terraform state (`terraform.tfstate`) once applied, because `helm_release` stores the values it sent. So:
- Mark the variable `sensitive = true` (hides it from CLI output, not from the state file).
- Use a remote backend with encryption at rest (S3+KMS, Terraform Cloud, etc.) and restrict who can read state.
- Never commit `terraform.tfstate` or a plaintext `.tfvars` containing the token to version control.

## 7. Apply

```bash
terraform init
terraform plan -var="cluster_name=my-cluster" -var="splunk_access_token=$SPLUNK_TOKEN"
terraform apply -var="cluster_name=my-cluster" -var="splunk_access_token=$SPLUNK_TOKEN"
```

## 8. Verify

```bash
kubectl get pods -n monitoring
kubectl logs -n monitoring -l app=splunk-otel-collector
```


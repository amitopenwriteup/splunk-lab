# AWS Components Monitoring with Splunk Observability Cloud

Covers monitoring **ALB, NLB, S3, Route 53**, and other common AWS services using Splunk Observability Cloud's native AWS integration (CloudWatch metric streams / API poller) — no agent installation required on AWS-managed services.

---

## How AWS Monitoring Works in Splunk Observability Cloud

```
AWS CloudWatch  --->  Splunk AWS Integration  --->  Splunk Observability Cloud
 (metrics/logs)         (Metric Streams or             (Infrastructure > AWS
                          API Poller)                    Navigators, Dashboards)
```

Splunk Observability Cloud pulls AWS service metrics directly from **CloudWatch** — it does not require the OTel Collector to be installed on AWS-managed resources like ALB, NLB, S3, or Route 53, since these are serverless/managed services with no host to install an agent on.

Two ingestion modes are available:

| Mode | How it works | Latency |
|---|---|---|
| **CloudWatch Metric Streams** (recommended) | AWS streams metrics in near real-time via Kinesis Firehose | ~1–2 minutes |
| **API Poller** | Splunk polls the CloudWatch API on an interval | 5–10+ minutes, subject to API rate limits |

---

## Prerequisites

| Item | Where to find/create it |
|---|---|
| AWS account with the services to monitor (ALB, NLB, S3, Route 53, etc.) | AWS Console |
| IAM role with read-only CloudWatch/service permissions | AWS IAM |
| Splunk Access Token or org admin access | Splunk Observability Cloud → Settings |
| (For Metric Streams) Kinesis Firehose + S3 bucket for AWS to stream into | AWS Console |

---

## Step 1 — Create the IAM Role for Splunk

1. In AWS Console, go to **IAM → Roles → Create role**.
2. Choose **Another AWS account**, and enter Splunk Observability Cloud's AWS account ID (provided during setup in the Splunk UI).
3. Enable **External ID** (Splunk generates this in the integration wizard — improves security).
4. Attach a read-only policy scoped to CloudWatch and the services you want to monitor, e.g.:
   - `CloudWatchReadOnlyAccess`
   - `AmazonS3ReadOnlyAccess` (for S3 metadata/tags)
   - `ElasticLoadBalancingReadOnly` (for ALB/NLB metadata/tags)
   - `AmazonRoute53ReadOnlyAccess` (for Route 53 metadata)
5. Name the role (e.g. `splunk-observability-readonly`) and create it.
6. Copy the **Role ARN** — you'll paste this into Splunk.

---

## Step 2 — Connect AWS to Splunk Observability Cloud

1. In Splunk Observability Cloud, go to **Data Management → Integrations** (or **Settings → Integrations**).
2. Search for and select **Amazon Web Services**.
3. Click **Connect**.
4. Choose ingestion method:
   - **CloudWatch Metric Streams** (recommended) — Splunk provides a CloudFormation template to auto-provision the Kinesis Firehose + stream config.
   - **API Poller** — simpler, no Firehose needed, but higher latency.
5. Paste the **Role ARN** and **External ID** from Step 1.
6. Select the **AWS regions** to monitor.
7. Select **namespaces/services** to sync (or select all) — make sure `ELB` (ALB/NLB), `S3`, and `Route53` are included.
8. Click **Save** / **Finish**.

### Validate the connection

Go to **Infrastructure → AWS** in the left nav. Within a few minutes, you should see AWS resources populating by service type.

---

## ALB (Application Load Balancer) Monitoring

**CloudWatch namespace:** `AWS/ApplicationELB`

### Key metrics

| Metric | Meaning |
|---|---|
| `RequestCount` | Total requests processed |
| `TargetResponseTime` | Latency from ALB to target |
| `HTTPCode_Target_4XX_Count` / `5XX_Count` | Target-side error counts |
| `HTTPCode_ELB_5XX_Count` | ALB-side errors (not reaching targets) |
| `HealthyHostCount` / `UnHealthyHostCount` | Target health |
| `ActiveConnectionCount` | Concurrent connections |
| `RejectedConnectionCount` | Connections rejected (ALB at capacity) |

### Validate
- **Infrastructure → AWS → ELB (Application)** navigator
- **Metrics finder** → search `aws.applicationelb.request_count` (or similar synced metric name)

### Suggested alert
Detector on `HTTPCode_Target_5XX_Count` or `UnHealthyHostCount` > 0 for sustained period.

---

## NLB (Network Load Balancer) Monitoring

**CloudWatch namespace:** `AWS/NetworkELB`

### Key metrics

| Metric | Meaning |
|---|---|
| `ActiveFlowCount` | Concurrent flows/connections |
| `NewFlowCount` | New flow rate |
| `ProcessedBytes` | Total data processed |
| `HealthyHostCount` / `UnHealthyHostCount` | Target health |
| `TCP_Client_Reset_Count` / `TCP_Target_Reset_Count` | Connection resets |
| `TCP_ELB_Reset_Count` | NLB-initiated resets |

### Validate
- **Infrastructure → AWS → ELB (Network)** navigator
- **Metrics finder** → search `aws.networkelb.*`

### Suggested alert
Detector on `UnHealthyHostCount` > 0, or a sudden drop in `NewFlowCount` (possible outage).

---

## S3 Monitoring

**CloudWatch namespace:** `AWS/S3`

> Note: S3 request-level metrics (`AllRequests`, `4xxErrors`, etc.) require **Request Metrics** to be explicitly enabled per-bucket in AWS (S3 console → bucket → Metrics → Request metrics), since they're not on by default like storage metrics.

### Key metrics

| Metric | Meaning | Always on? |
|---|---|---|
| `BucketSizeBytes` | Total bucket size | Yes (daily) |
| `NumberOfObjects` | Object count | Yes (daily) |
| `AllRequests` | Total request count | Requires Request Metrics enabled |
| `4xxErrors` / `5xxErrors` | Client/server errors | Requires Request Metrics enabled |
| `FirstByteLatency` / `TotalRequestLatency` | Latency | Requires Request Metrics enabled |

### Enable request metrics (if needed)

```bash
aws s3api put-bucket-metrics-configuration \
  --bucket <your-bucket-name> \
  --id EntireBucket \
  --metrics-configuration '{"Id":"EntireBucket"}'
```

### Validate
- **Infrastructure → AWS → S3** navigator
- **Metrics finder** → search `aws.s3.bucket_size_bytes`, `aws.s3.number_of_objects`

### Suggested alert
Detector on `4xxErrors`/`5xxErrors` rate, or `BucketSizeBytes` growth rate (cost/capacity control).

---

## Route 53 Monitoring

**CloudWatch namespace:** `AWS/Route53`

### Key metrics

| Metric | Meaning |
|---|---|
| `HealthCheckStatus` | 1 = healthy, 0 = unhealthy (per configured health check) |
| `HealthCheckPercentageHealthy` | % of health-checking regions reporting healthy |
| `ConnectionTime` | Time to establish connection during health check |
| `DNSQueries` (via Route 53 Resolver Query Logging) | Query volume, requires separate log-based setup |

> Note: Route 53 metrics are mostly **health check** metrics. DNS query volume/analytics require enabling **Route 53 Resolver Query Logging** to CloudWatch Logs or S3 separately, then ingesting those logs.

### Validate
- **Infrastructure → AWS → Route53** navigator
- **Metrics finder** → search `aws.route53.health_check_status`

### Suggested alert
Detector on `HealthCheckStatus` == 0 (immediate failover/incident signal).

---

## Other Common AWS Components (Brief)

| Service | Namespace | Key metrics |
|---|---|---|
| **EC2** | `AWS/EC2` | `CPUUtilization`, `NetworkIn/Out`, `StatusCheckFailed` |
| **RDS** | `AWS/RDS` | `CPUUtilization`, `DatabaseConnections`, `FreeStorageSpace`, `ReadLatency`/`WriteLatency` |
| **Lambda** | `AWS/Lambda` | `Invocations`, `Errors`, `Duration`, `Throttles`, `ConcurrentExecutions` |
| **CloudFront** | `AWS/CloudFront` | `Requests`, `4xxErrorRate`/`5xxErrorRate`, `BytesDownloaded` |
| **API Gateway** | `AWS/ApiGateway` | `Count`, `4XXError`/`5XXError`, `Latency` |
| **DynamoDB** | `AWS/DynamoDB` | `ConsumedReadCapacityUnits`, `ThrottledRequests`, `SystemErrors` |
| **SQS** | `AWS/SQS` | `ApproximateNumberOfMessagesVisible`, `ApproximateAgeOfOldestMessage` |

Each of these follows the same pattern: enable the namespace in the AWS integration, then find its navigator under **Infrastructure → AWS**.

---

## Building Dashboards

1. **Dashboards → Built-in Dashboards** — check for pre-built AWS service dashboards (ALB, NLB, S3, Route 53 often have defaults).
2. To customize, **clone** the built-in dashboard, then add/remove charts.
3. Use **Group by** on tags like `LoadBalancer`, `BucketName`, or `HostedZoneId` to scope views per resource.

---

## Creating Alerts/Detectors

1. **Alerts → Detectors → New Detector**.
2. Select the AWS metric (e.g. `aws.applicationelb.target_response_time`).
3. Set a static or dynamic (historical anomaly) threshold.
4. Scope by tag (e.g. specific load balancer or bucket).
5. Add a notification target (email, Slack, PagerDuty, webhook).
6. Save and activate.

---

## Troubleshooting

| Issue | Check |
|---|---|
| No AWS resources appear at all | Confirm IAM role trust policy has the correct Splunk account ID + External ID |
| Some services show data, others don't | Confirm the specific namespace (e.g. `AWS/S3`) is selected in the integration's service list |
| S3 request metrics missing | Confirm **Request Metrics** is enabled per-bucket in AWS — not on by default |
| Route 53 query volume missing | Confirm **Resolver Query Logging** is separately enabled and routed to CloudWatch Logs/S3 |
| Data delayed by 10+ minutes | You're likely on API Poller mode — switch to CloudWatch Metric Streams for near real-time data |
| Metrics stopped updating | Check AWS-side IAM role hasn't expired/been revoked, and Firehose delivery stream (if using Metric Streams) is still active |

---

## Reference

- Splunk AWS integration docs: https://docs.splunk.com/observability/en/gdi/get-data-in/connect/aws/aws-setup.html
- AWS CloudWatch metrics reference: https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/aws-services-cloudwatch-metrics.html

# README 1 --- ECS Fargate Monitoring Stack as One Combined Service

## Purpose

This architecture combines **Grafana, Prometheus, and CloudWatch
Exporter into one ECS Fargate task definition and one ECS service**.

This is the simpler architecture for the current `testcluster`
environment.

The application services remain separate:

``` text
ECS Cluster: testcluster
│
├── frontendservice
│   └── Frontend container :80
│
├── backendservice
│   └── Backend container :5000
│
└── monitoring-service
    └── monitoring-stack task
        ├── Grafana :3000
        ├── Prometheus :9090
        └── CloudWatch Exporter :9106
```

All three monitoring containers run in the same Fargate task.

With `awsvpc` networking, the containers in the same task share the task
network namespace. Therefore:

``` text
Grafana       → http://localhost:9090
Prometheus    → http://localhost:9106
```

No ECS Service Connect or Cloud Map is required for communication
between these three containers.

------------------------------------------------------------------------

# 1. Final Architecture

``` text
                         INTERNET
                            |
                            v
                           ALB
                            |
             +--------------+--------------+
             |                             |
             v                             v
         /grafana*                         /
             |                             |
             v                             v
       monitoring-tg                 frontend-tg
             |                             |
             v                             v
      monitoring task                 frontend ECS
             |
      +------+----------------+
      |                       |
      v                       v
   Grafana                Prometheus
    :3000                   :9090
                              |
                              | localhost:9106
                              v
                       CloudWatch Exporter
                              :9106
                                |
                                v
                         AWS CloudWatch
```

The existing backend remains:

``` text
ALB :5000
    |
    v
backendservice
    |
    v
Backend :5000
```

------------------------------------------------------------------------

# 2. Important Design Decision

The monitoring task contains:

``` text
grafana
prometheus
cloudwatch-exporter
```

The CloudWatch Exporter does **not** need an ALB.

Only Grafana and Prometheus need ALB access.

The final public paths are:

``` text
http://CURRENT-ALB-DNS/grafana/
http://CURRENT-ALB-DNS/prometheus/
```

CloudWatch Exporter remains private.

------------------------------------------------------------------------

# 3. Before You Start

Use the AWS Console only for this procedure.

AWS Region:

``` text
us-east-1
```

ECS Cluster:

``` text
testcluster
```

Use your current ALB DNS name. In the current environment it is:

``` text
albtest-1583924668.us-east-1.elb.amazonaws.com
```

If AWS has assigned a different ALB DNS name, use the current value
instead.

Do not delete the existing monitoring services until the new combined
service is working.

------------------------------------------------------------------------

# 4. Images Required

The combined task uses these existing ECR images:

``` text
394711685791.dkr.ecr.us-east-1.amazonaws.com/monitoring-grafana
394711685791.dkr.ecr.us-east-1.amazonaws.com/monitoring-prometheus
394711685791.dkr.ecr.us-east-1.amazonaws.com/monitoring-cloudwatch-exporter
```

You do not need to rebuild the images.

------------------------------------------------------------------------

# 5. IAM Roles

## 5.1 Task Execution Role

Use the existing:

``` text
TaskExecutionRole
```

Go to:

**AWS Console → IAM → Roles → TaskExecutionRole**

Verify that it can:

-   Pull images from ECR
-   Send logs to CloudWatch Logs
-   Read the S3 object used by Grafana environment variables

Your Grafana task currently uses:

``` text
arn:aws:s3:::ecomm-loki-logs-champ/grafana.env
```

Therefore the execution role must be able to read that object.

If the existing role already works for the current Grafana task, keep
it.

------------------------------------------------------------------------

# 6. Create a Combined Task Definition

Go to:

**AWS Console → ECS → Task definitions**

Choose:

**Create new task definition**

Select:

``` text
AWS Fargate
```

Family:

``` text
monitoring-stack
```

CPU:

``` text
1 vCPU
```

Memory:

``` text
3 GB
```

These match the current monitoring task size you are already using.

For heavier Grafana/Prometheus workloads, increase this later.

------------------------------------------------------------------------

# 7. Task IAM Role

For the combined task, all containers share the task IAM role.

For this test environment, you can use:

``` text
ecsCloudWatchExporterTaskRole
```

because it already contains the CloudWatch read permissions required by
the exporter.

### Important production note

A shared task role means Grafana and Prometheus also run with the task
role permissions.

For production, create a dedicated least-privilege combined monitoring
role.

For the current test environment, keeping the existing role is
acceptable if you understand this limitation.

------------------------------------------------------------------------

# 8. Add Grafana Container

Inside the task definition choose:

**Add container**

Container name:

``` text
grafana
```

Image:

``` text
394711685791.dkr.ecr.us-east-1.amazonaws.com/monitoring-grafana
```

Use your current image digest/tag.

Container port:

``` text
3000
```

Protocol:

``` text
TCP
```

Port name:

``` text
grafana-3000-tcp
```

App protocol:

``` text
HTTP
```

Set:

``` text
Essential = Yes
```

------------------------------------------------------------------------

# 9. Grafana Environment File

For the Grafana container, add the existing S3 environment file:

``` text
arn:aws:s3:::ecomm-loki-logs-champ/grafana.env
```

Type:

``` text
S3
```

This matches your current Grafana task definition.

Do not put the Grafana password directly into the Docker image.

------------------------------------------------------------------------

# 10. Grafana Logging

Use:

``` text
Log driver:
awslogs
```

Log group:

``` text
/ecs/monitoring-stack-grafana
```

Region:

``` text
us-east-1
```

Stream prefix:

``` text
ecs
```

You can use the existing `/ecs/monitoring-grafana` log group instead if
preferred.

------------------------------------------------------------------------

# 11. Add Prometheus Container

Choose:

**Add container**

Container name:

``` text
prometheus
```

Image:

``` text
394711685791.dkr.ecr.us-east-1.amazonaws.com/monitoring-prometheus
```

Use your current image digest/tag.

Container port:

``` text
9090
```

Protocol:

``` text
TCP
```

Port name:

``` text
prometheus-9090-tcp
```

App protocol:

``` text
HTTP
```

Essential:

``` text
Yes
```

------------------------------------------------------------------------

# 12. Prometheus Configuration

Your Prometheus configuration must use localhost for CloudWatch
Exporter.

Change the CloudWatch Exporter target to:

``` text
localhost:9106
```

Do not use:

``` text
cloudwatch-exporter:9106
```

That hostname is for the separate-service architecture.

For this combined-task architecture:

``` text
Prometheus
    |
    +---- localhost:9106
              |
              v
      CloudWatch Exporter
```

Keep the Prometheus server configuration itself on:

``` text
9090
```

------------------------------------------------------------------------

# 13. Prometheus External URL

Because Prometheus is exposed through:

``` text
/prometheus/
```

make sure the Prometheus container is configured with the appropriate
external URL:

``` text
http://CURRENT-ALB-DNS/prometheus/
```

Use the current ALB DNS name.

If your existing Prometheus image already contains this configuration,
do not change it.

------------------------------------------------------------------------

# 14. Prometheus Logging

Use:

``` text
Log driver:
awslogs
```

Log group:

``` text
/ecs/monitoring-stack-prometheus
```

Region:

``` text
us-east-1
```

Stream prefix:

``` text
ecs
```

------------------------------------------------------------------------

# 15. Add CloudWatch Exporter Container

Choose:

**Add container**

Container name:

``` text
cloudwatch-exporter
```

Image:

``` text
394711685791.dkr.ecr.us-east-1.amazonaws.com/monitoring-cloudwatch-exporter
```

Use your current image digest/tag.

Container port:

``` text
9106
```

Protocol:

``` text
TCP
```

Port name:

``` text
cloudwatch-exporter-9106-tcp
```

App protocol:

``` text
HTTP
```

Essential:

``` text
Yes
```

------------------------------------------------------------------------

# 16. CloudWatch Exporter IAM

The combined task uses:

``` text
ecsCloudWatchExporterTaskRole
```

Verify that it has:

``` text
cloudwatch:GetMetricData
cloudwatch:GetMetricStatistics
cloudwatch:ListMetrics
```

with the required resource permissions.

The exporter uses the ECS task role instead of hard-coded AWS access
keys.

------------------------------------------------------------------------

# 17. CloudWatch Exporter Logging

Use:

``` text
Log driver:
awslogs
```

Log group:

``` text
/ecs/monitoring-stack-cloudwatch-exporter
```

Region:

``` text
us-east-1
```

Stream prefix:

``` text
ecs
```

------------------------------------------------------------------------

# 18. Do Not Add an OTEL Sidecar Unless You Need It

Your existing Prometheus task definition contains:

``` text
aws-otel-collector
```

The basic monitoring architecture does not require this sidecar.

The core stack is:

``` text
Grafana
Prometheus
CloudWatch Exporter
```

If you are not explicitly using the OTEL collector for another purpose,
leave it out of the combined task.

If you are using it for ECS/OTEL telemetry, keep it as a fourth
container.

------------------------------------------------------------------------

# 19. Review the Combined Task

The final task should contain:

``` text
monitoring-stack
│
├── grafana
│     :3000
│
├── prometheus
│     :9090
│
└── cloudwatch-exporter
      :9106
```

All three must be in the same task definition.

Choose:

**Create**

------------------------------------------------------------------------

# 20. Create Monitoring Target Groups

You need two target groups.

## Grafana target group

Go to:

**AWS Console → EC2 → Target Groups → Create target group**

Choose:

``` text
Target type:
IP addresses
```

Name:

``` text
monitoring-grafana-tg
```

Protocol:

``` text
HTTP
```

Port:

``` text
3000
```

VPC:

``` text
Your ECS VPC
```

Health check:

``` text
Protocol: HTTP
Path: /api/health
Port: traffic-port
Success code: 200
```

Create the target group.

Fargate/`awsvpc` requires IP target groups.
citeturn0search0turn0search12

------------------------------------------------------------------------

# 21. Prometheus Target Group

Go to:

**EC2 → Target Groups → Create target group**

Choose:

``` text
Target type:
IP addresses
```

Name:

``` text
monitoring-prometheus-tg
```

Protocol:

``` text
HTTP
```

Port:

``` text
9090
```

VPC:

``` text
Your ECS VPC
```

Health check:

``` text
Protocol: HTTP
Path: /-/healthy
Port: traffic-port
Success code: 200
```

Create the target group.

------------------------------------------------------------------------

# 22. Create the ECS Service

Go to:

**ECS → Clusters → testcluster → Services → Create**

Select:

``` text
Deployment configuration:
Service
```

Task definition:

``` text
monitoring-stack
```

Service name:

``` text
monitoring-service
```

Scheduling strategy:

``` text
Replica
```

Desired tasks:

``` text
1
```

Launch type:

``` text
Fargate
```

------------------------------------------------------------------------

# 23. Networking

Use the same:

``` text
VPC
```

and private subnets used by your current monitoring services.

Public IP:

``` text
OFF
```

Security group:

``` text
ECS Monitoring Security Group
```

Do not expose the task directly to the Internet.

------------------------------------------------------------------------

# 24. Attach Grafana to the ALB

In the ECS service creation screen under:

**Load balancing**

Select:

``` text
Application Load Balancer
```

Select your existing ALB.

Select the existing HTTP listener:

``` text
HTTP :80
```

Add/load balance the container:

``` text
grafana :3000
```

Select:

``` text
monitoring-grafana-tg
```

ECS supports associating multiple target groups with a service when
using the ECS deployment controller. citeturn0search0

------------------------------------------------------------------------

# 25. Attach Prometheus to the Same ALB

Add another load-balancer mapping for:

``` text
prometheus :9090
```

Target group:

``` text
monitoring-prometheus-tg
```

This is important:

``` text
One ECS service
        |
        +---- Grafana :3000 → monitoring-grafana-tg
        |
        +---- Prometheus :9090 → monitoring-prometheus-tg
```

The same task can therefore be registered in both target groups on
different ports. ALB target groups support targets being registered in
multiple target groups. citeturn0search5

------------------------------------------------------------------------

# 26. Security Group Rules

Your monitoring security group should allow:

``` text
TCP 3000
Source: ALB security group
```

and:

``` text
TCP 9090
Source: ALB security group
```

CloudWatch Exporter does not need an ALB.

Do not allow:

``` text
0.0.0.0/0
```

to ports:

``` text
3000
9090
9106
```

------------------------------------------------------------------------

# 27. ALB Listener Rules

Go to:

**EC2 → Load Balancers → your ALB → Listeners → HTTP :80**

Keep the existing frontend default rule.

Create:

### Rule 1

Condition:

``` text
Path = /grafana*
```

Action:

``` text
Forward to monitoring-grafana-tg
```

### Rule 2

Condition:

``` text
Path = /prometheus*
```

Action:

``` text
Forward to monitoring-prometheus-tg
```

The listener should effectively be:

``` text
HTTP :80

Priority 10
/grafana*
      ↓
monitoring-grafana-tg

Priority 20
/prometheus*
      ↓
monitoring-prometheus-tg

Default
/
      ↓
frontend-tg
```

------------------------------------------------------------------------

# 28. Verify Target Health

Go to:

**EC2 → Target Groups**

Check:

``` text
monitoring-grafana-tg
```

Expected:

``` text
Healthy
```

Then:

``` text
monitoring-prometheus-tg
```

Expected:

``` text
Healthy
```

If either target is unhealthy, do not delete the old monitoring services
yet.

------------------------------------------------------------------------

# 29. Test Grafana

Open:

``` text
http://CURRENT-ALB-DNS/grafana/
```

Expected:

``` text
Grafana login
```

------------------------------------------------------------------------

# 30. Configure Grafana Prometheus Data Source

Inside Grafana:

**Connections → Data Sources → Add data source → Prometheus**

URL:

``` text
http://localhost:9090
```

This is the key change from your current setup.

Do not use:

``` text
http://prometheus:9090
```

because there is no need for DNS when both containers are in the same
task.

Click:

**Save & Test**

Expected:

``` text
Successfully queried the Prometheus API.
```

------------------------------------------------------------------------

# 31. Test Prometheus

Open:

``` text
http://CURRENT-ALB-DNS/prometheus/
```

Go to:

**Status → Targets**

The Prometheus target itself should be available.

------------------------------------------------------------------------

# 32. Prometheus → CloudWatch Exporter

Prometheus should scrape:

``` text
localhost:9106
```

Therefore:

``` text
Prometheus
    |
    | localhost:9106
    v
CloudWatch Exporter
```

No Cloud Map.

No Service Connect.

No DNS.

------------------------------------------------------------------------

# 33. Test CloudWatch Exporter

CloudWatch Exporter is private.

You should not expose:

``` text
ALB:9106
```

Use ECS Exec if enabled, or inspect the container logs.

Expected endpoint inside the task:

``` text
http://localhost:9106/metrics
```

------------------------------------------------------------------------

# 34. Verify the Complete Flow

The final test is:

``` text
Browser
   |
   v
ALB
   |
   +---- /grafana
   |       |
   |       v
   |    Grafana
   |       |
   |       | localhost:9090
   |       v
   |    Prometheus
   |       |
   |       | localhost:9106
   |       v
   |    CloudWatch Exporter
   |       |
   |       v
   |    CloudWatch
   |
   +---- /prometheus
           |
           v
       Prometheus
```

------------------------------------------------------------------------

# 35. Migration

Do not immediately delete:

``` text
grafana-service
prometheus-service
cloudwatch-exporter-service
```

First verify:

-   Monitoring task is RUNNING
-   Grafana target is healthy
-   Prometheus target is healthy
-   Grafana loads
-   Prometheus loads
-   Grafana Save & Test succeeds
-   Prometheus can scrape CloudWatch Exporter

Only then remove the old monitoring services.

------------------------------------------------------------------------

# 36. Advantages

This architecture gives you:

-   One monitoring ECS service
-   One monitoring task definition
-   No Service Connect
-   No Cloud Map
-   No internal DNS configuration
-   Simple Grafana → Prometheus communication
-   Simple Prometheus → CloudWatch Exporter communication
-   One deployment unit

------------------------------------------------------------------------

# 37. Disadvantages

The three monitoring components are now coupled.

If the monitoring task stops:

``` text
Grafana              DOWN
Prometheus           DOWN
CloudWatch Exporter  DOWN
```

They also scale together.

For production, separate ECS services are generally more flexible.

For your current testing environment, this combined design is much
simpler.

------------------------------------------------------------------------

# 38. Final Port Reference

  Component               Port Public through ALB
  --------------------- ------ --------------------
  Frontend                  80 Yes
  Backend                 5000 Existing
  Grafana                 3000 `/grafana*`
  Prometheus              9090 `/prometheus*`
  CloudWatch Exporter     9106 No

------------------------------------------------------------------------

# 39. Final URLs

Frontend:

``` text
http://CURRENT-ALB-DNS/
```

Grafana:

``` text
http://CURRENT-ALB-DNS/grafana/
```

Prometheus:

``` text
http://CURRENT-ALB-DNS/prometheus/
```

CloudWatch Exporter:

``` text
Private only
```

------------------------------------------------------------------------

# 40. Success Criteria

The combined architecture is complete when:

-   [ ] `monitoring-stack` task definition exists
-   [ ] Grafana container is running
-   [ ] Prometheus container is running
-   [ ] CloudWatch Exporter container is running
-   [ ] `monitoring-service` is running
-   [ ] Grafana target is healthy
-   [ ] Prometheus target is healthy
-   [ ] `/grafana/` works
-   [ ] `/prometheus/` works
-   [ ] Grafana datasource uses `http://localhost:9090`
-   [ ] Grafana Save & Test succeeds
-   [ ] Prometheus scrapes `localhost:9106`
-   [ ] CloudWatch Exporter returns metrics
-   [ ] CloudWatch metrics appear in Prometheus
-   [ ] Grafana can query Prometheus

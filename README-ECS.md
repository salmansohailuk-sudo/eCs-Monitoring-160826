# ECS Fargate Deployment Guide
# E-Commerce + Monitoring Stack


# chmod 755 chmod +x ~/eCs-Monitoring-160826/frontend/20-backend-url.sh

note: ALB Target health setting for grafana

/api/health

ALB Target health setting for prometheus

/prometheus/-/healthy

Check Prometheus health - curl http://your-alb-dns/prometheus/-/healthy

## new Iam TaskRoleECSPolicy-expanded.
```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchLogs",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchMetrics",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2Discovery",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeVolumes",
        "ec2:DescribeTags",
        "ec2:DescribeRegions",
        "ec2:DescribeAvailabilityZones"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSDiscovery",
      "Effect": "Allow",
      "Action": [
        "ecs:ListClusters",
        "ecs:DescribeClusters",
        "ecs:ListServices",
        "ecs:DescribeServices",
        "ecs:ListTasks",
        "ecs:DescribeTasks",
        "ecs:ListContainerInstances",
        "ecs:DescribeContainerInstances"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LoadBalancerDiscovery",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:DescribeListeners"
      ],
      "Resource": "*"
    },
    {
      "Sid": "RDSDiscovery",
      "Effect": "Allow",
      "Action": [
        "rds:DescribeDBInstances",
        "rds:DescribeDBClusters"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LambdaDiscovery",
      "Effect": "Allow",
      "Action": [
        "lambda:ListFunctions",
        "lambda:GetFunctionConfiguration"
      ],
      "Resource": "*"
    },
    {
      "Sid": "APIGatewayDiscovery",
      "Effect": "Allow",
      "Action": [
        "apigateway:GET"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DynamoDBDiscovery",
      "Effect": "Allow",
      "Action": [
        "dynamodb:ListTables",
        "dynamodb:DescribeTable"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SQSDiscovery",
      "Effect": "Allow",
      "Action": [
        "sqs:ListQueues",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "*"
    },
    {
      "Sid": "SNSDiscovery",
      "Effect": "Allow",
      "Action": [
        "sns:ListTopics",
        "sns:GetTopicAttributes"
      ],
      "Resource": "*"
    },
    {
      "Sid": "KinesisDiscovery",
      "Effect": "Allow",
      "Action": [
        "kinesis:ListStreams",
        "kinesis:DescribeStream"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EFSDiscovery",
      "Effect": "Allow",
      "Action": [
        "elasticfilesystem:DescribeFileSystems",
        "elasticfilesystem:DescribeMountTargets"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TagDiscovery",
      "Effect": "Allow",
      "Action": [
        "tag:GetResources"
      ],
      "Resource": "*"
    }
  ]
}
```

# Seps to create ECS Task Definations and environment variables.
# ECS Task Definition Environment Variables

## frontend

```
BACKEND_URL = http://backend.testcluster.local:5000
```

## backend

```
AWS_REGION            = us-east-1
DB_HOST               = ecomm.c25accikcy7j.us-east-1.rds.amazonaws.com
DB_USER               = admin
DB_PASSWORD           = Cloud123
DB_NAME               = ecomm
DB_PORT               = 3306
STRIPE_SECRET_KEY     = sk_test_...
STRIPE_WEBHOOK_SECRET = whsec_...
BASE_URL              = http://alb-1198490024.us-east-1.elb.amazonaws.com
```

`BASE_URL` matters if your backend builds redirect/callback URLs anywhere (e.g. Stripe checkout success/cancel URLs) — it should point at the ALB, not the EC2 IP, once running in ECS.

**Security note:** `DB_PASSWORD`, `STRIPE_SECRET_KEY`, and `STRIPE_WEBHOOK_SECRET` shouldn't go in as plaintext `environment` entries in a task definition — anyone with `ecs:DescribeTaskDefinition` can read them. Since this is a test project it's not critical, but the low-effort fix is to put them in AWS Secrets Manager (or SSM Parameter Store) and reference them via the task definition's `secrets` block instead of `environment`.

## nginx-exporter

No environment variables — it's driven by a command override, not env vars:

```
command = ["--nginx.scrape-uri=http://frontend.testcluster.local/nginx_status"]
```

## cloudwatch-exporter

```
AWS_REGION = us-east-1
```

It also needs IAM permissions to call CloudWatch's `GetMetricData`/`ListMetrics` — that's a task role, not an env var, so make sure the task definition's `taskRoleArn` has a policy allowing that.

## prometheus

No environment variables needed — this is the one already solved by baking `prometheus.ecs.yml` into the `:ecs` image tag, so it self-configures with the Cloud Map hostnames.

## grafana

```
GF_SECURITY_ADMIN_USER        = admin
GF_SECURITY_ADMIN_PASSWORD    = admin
GF_SERVER_ROOT_URL            = http://alb-1198490024.us-east-1.elb.amazonaws.com:3000/
GF_SERVER_SERVE_FROM_SUB_PATH = false
PROMETHEUS_URL                = http://prometheus.testcluster.local:9090
```

This guide deploys the application and monitoring stack to Amazon ECS Fargate.

The existing ECS cluster and existing Application Load Balancer are reused.

---

# 1. AWS Environment

Region:

```text
us-east-1
```

Existing ECS Cluster:

```text
testcluster
```

Existing Application Load Balancer:

```text
albtest-1244121495.us-east-1.elb.amazonaws.com
```

Existing application:

```text
Frontend
Backend
```

Existing ALB listeners:

```text
HTTP :80
HTTP :5000
```

Existing frontend and backend target groups should remain unchanged.

---

# 2. Final ECS Architecture

```text
                         INTERNET
                             |
                             v
                           ALB
                             |
       albtest-1244121495.us-east-1.elb.amazonaws.com
                             |
                         HTTP :80
                             |
        +--------------------+--------------------+
        |                    |                    |
        v                    v                    v
     /grafana          /prometheus             /
        |                    |                    |
        v                    v                    v
  Grafana Target      Prometheus Target     Frontend Target
      Group                 Group                Group
        |                    |                    |
        v                    v                    v
   Grafana ECS         Prometheus ECS       Frontend ECS
      :3000                 :9090                :80
                             |
                             |
                             v
                    CloudWatch Exporter ECS
                             :9106
                             |
                             v
                       AWS CloudWatch
```

Existing backend:

```text
ALB :5000
    |
    v
Backend Target Group
    |
    v
Backend ECS
    |
    v
Backend :5000
```

---

# 3. ECS Services

Existing:

```text
frontend-service
backend-service
```

New:

```text
grafana-service
prometheus-service
cloudwatch-exporter-service
```

---

# 4. ECR Repositories

Create these repositories:

```text
ecomm-frontend

ecomm-backend

monitoring-grafana

monitoring-prometheus

monitoring-cloudwatch-exporter
```

---

# 5. Build and Push Images

From the project root:

```bash
chmod +x ecr-tag-push.sh
```

Run:

```bash
./ecr-tag-push.sh
```

This builds and pushes:

```text
ecomm-frontend

ecomm-backend

monitoring-grafana

monitoring-prometheus

monitoring-cloudwatch-exporter
```

---

# 6. ECR Image URLs

Replace `ACCOUNT_ID` with your AWS account ID.

Frontend:

```text
ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ecomm-frontend:latest
```

Backend:

```text
ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ecomm-backend:latest
```

Grafana:

```text
ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/monitoring-grafana:latest
```

Prometheus:

```text
ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/monitoring-prometheus:latest
```

CloudWatch Exporter:

```text
ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/monitoring-cloudwatch-exporter:latest
```

---

# 7. ECS Task Execution Role

Use the existing ECS task execution role if available:

```text
ecsTaskExecutionRole
```

It should have:

```text
AmazonECSTaskExecutionRolePolicy
```

This allows ECS to:

- Pull images from ECR
- Send logs to CloudWatch
- Execute ECS task operations

---

# 8. CloudWatch Exporter Task Role

Create a separate IAM role:

```text
ecsCloudWatchExporterTaskRole
```


# ecs-cloudwatch-logs-policy

Example:

```json

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }
  ]
}

```


Trust relationship:

```text
ecs-tasks.amazonaws.com
```

Attach a CloudWatch read policy.

Example:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CloudWatchMetrics",
      "Effect": "Allow",
      "Action": [
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2Discovery",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSDiscovery",
      "Effect": "Allow",
      "Action": [
        "ecs:ListClusters",
        "ecs:DescribeClusters",
        "ecs:ListServices",
        "ecs:DescribeServices",
        "ecs:ListTasks",
        "ecs:DescribeTasks"
      ],
      "Resource": "*"
    },
    {
      "Sid": "LoadBalancerDiscovery",
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DescribeLoadBalancers",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth"
      ],
      "Resource": "*"
    },
    {
      "Sid": "RDSDiscovery",
      "Effect": "Allow",
      "Action": [
        "rds:DescribeDBInstances"
      ],
      "Resource": "*"
    },
    {
      "Sid": "TagDiscovery",
      "Effect": "Allow",
      "Action": [
        "tag:GetResources"
      ],
      "Resource": "*"
    }
  ]
}
```

Use least privilege where possible.

This role is the:

```text
TASK ROLE
```

It is different from:

```text
TASK EXECUTION ROLE
```

---

# 9. ECS Security Groups

Create or use an ECS monitoring security group.

Allow the ALB security group to access:

```text
TCP 3000
TCP 9090
```

For CloudWatch Exporter allow:

```text
Prometheus ECS Security Group
        |
        +---- TCP 9106
```

Do NOT allow:

```text
0.0.0.0/0
```

to ports:

```text
3000
9090
9106
```

The monitoring containers should not be directly exposed to the Internet.

---

# 10. Grafana Target Group

Go to:

```text
AWS Console
    |
    +-- EC2
        |
        +-- Target Groups
```

Create:

```text
grafana-tg
```

Target type:

```text
IP addresses
```

Protocol:

```text
HTTP
```

Port:

```text
3000
```

Use the same VPC as ECS.

---

# 11. Grafana Health Check

Configure:

```text
Protocol:
HTTP

Path:
/api/health

Port:
traffic-port

Success codes:
200
```

Expected:

```text
Healthy
```

---

# 12. Prometheus Target Group

Create:

```text
prometheus-tg
```

Target type:

```text
IP addresses
```

Protocol:

```text
HTTP
```

Port:

```text
9090
```

Use the same VPC as ECS.

---

# 13. Prometheus Health Check

Configure:

```text
Protocol:
HTTP

Path:
/-/healthy

Port:
traffic-port

Success codes:
200
```

Expected:

```text
Healthy
```

---

# 14. Existing ALB

Go to:

```text
EC2
    |
    +-- Load Balancers
```

Select:

```text
albtest-1244121495.us-east-1.elb.amazonaws.com
```

Open:

```text
Listeners
```

Select:

```text
HTTP :80
```

Do not create a second ALB.

---

# 15. Grafana ALB Rule

Add a listener rule to the existing HTTP :80 listener.

Condition:

```text
Path is:
/grafana*
```

Action:

```text
Forward to:
grafana-tg
```

Example priority:

```text
10
```

Use any unused priority if `10` already exists.

---

# 16. Prometheus ALB Rule

Add another rule.

Condition:

```text
Path is:
/prometheus*
```

Action:

```text
Forward to:
prometheus-tg
```

Example priority:

```text
20
```

Use any unused priority if `20` already exists.

---

# 17. Existing Frontend Rule

Keep the existing frontend rule.

Example:

```text
Default Rule
    |
    v
Frontend Target Group
```

Therefore:

```text
/
```

continues to serve the frontend.

---

# 18. Final ALB Rules

The final HTTP :80 listener should effectively be:

```text
HTTP :80
    |
    +-- Priority 10
    |       |
    |       +-- /grafana*
    |              |
    |              v
    |          grafana-tg
    |
    +-- Priority 20
    |       |
    |       +-- /prometheus*
    |              |
    |              v
    |          prometheus-tg
    |
    +-- Default
            |
            v
        frontend-tg
```

---

# 19. Create Grafana Task Definition

Go to:

```text
ECS
    |
    +-- Task Definitions
        |
        +-- Create new task definition
```

Family:

```text
monitoring-grafana
```

Launch type:

```text
AWS Fargate
```

CPU:

```text
0.5 vCPU
```

Memory:

```text
1 GB
```

Task execution role:

```text
ecsTaskExecutionRole
```

---

# 20. Grafana Container

Container name:

```text
grafana
```

Image:

```text
ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/monitoring-grafana:latest
```

Port:

```text
3000
```

Protocol:

```text
TCP
```

Essential:

```text
Yes
```

---

# 21. Grafana Environment Variables

Use:

```text
GF_SECURITY_ADMIN_USER=admin
```

```text
GF_SECURITY_ADMIN_PASSWORD=admin
```

Because Grafana is accessed through:

```text
/grafana/
```

configure:

```text
GF_SERVER_ROOT_URL=http://albtest-1244121495.us-east-1.elb.amazonaws.com/grafana/
```

and:

```text
GF_SERVER_SERVE_FROM_SUB_PATH=true
```

For production, store the Grafana password in:

```text
AWS Secrets Manager
```

instead of directly in the task definition.

---

# 22. Create Grafana ECS Service

Go to:

```text
ECS
    |
    +-- Clusters
        |
        +-- testcluster
            |
            +-- Services
                |
                +-- Create
```

Service name:

```text
grafana-service
```

Task definition:

```text
monitoring-grafana
```

Desired count:

```text
1
```

Launch type:

```text
Fargate
```

---

# 23. Grafana Networking

Use:

```text
Existing VPC
```

Select the same private subnets used by your ECS application.

Public IP:

```text
OFF
```

Security group:

```text
ECS Monitoring Security Group
```

The ALB communicates with Grafana over the private network.

---

# 24. Grafana Load Balancer

Select:

```text
Existing Application Load Balancer
```

ALB:

```text
albtest-1244121495.us-east-1.elb.amazonaws.com
```

Listener:

```text
HTTP :80
```

Target group:

```text
grafana-tg
```

Container:

```text
grafana:3000
```

---

# 25. Create Prometheus Task Definition

Create:

```text
monitoring-prometheus
```

Launch:

```text
AWS Fargate
```

CPU:

```text
0.5 vCPU
```

Memory:

```text
1 GB
```

Execution role:

```text
ecsTaskExecutionRole
```

---

# 26. Prometheus Container

Name:

```text
prometheus
```

Image:

```text
ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/monitoring-prometheus:latest
```

Port:

```text
9090
```

Protocol:

```text
TCP
```

Essential:

```text
Yes
```

---

# 27. Prometheus Command

Prometheus must know that it is exposed through:

```text
/prometheus/
```

Use:

```text
--config.file=/etc/prometheus/prometheus.yml
```

and:

```text
--storage.tsdb.path=/prometheus
```

and:

```text
--web.external-url=http://albtest-1244121495.us-east-1.elb.amazonaws.com/prometheus/
```

---

# 28. Create Prometheus ECS Service

Service name:

```text
prometheus-service
```

Task definition:

```text
monitoring-prometheus
```

Desired count:

```text
1
```

Launch:

```text
Fargate
```

Public IP:

```text
OFF
```

---

# 29. Prometheus Load Balancer

Use the existing ALB.

Listener:

```text
HTTP :80
```

Target group:

```text
prometheus-tg
```

Container:

```text
prometheus:9090
```

---

# 30. CloudWatch Exporter Task Definition

Create:

```text
monitoring-cloudwatch-exporter
```

Launch:

```text
AWS Fargate
```

CPU:

```text
0.25 vCPU
```

Memory:

```text
512 MB
```

Task execution role:

```text
ecsTaskExecutionRole
```

Task role:

```text
ecsCloudWatchExporterTaskRole
```

---

# 31. CloudWatch Exporter Container

Container name:

```text
cloudwatch-exporter
```

Image:

```text
ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/monitoring-cloudwatch-exporter:latest
```

Port:

```text
9106
```

Protocol:

```text
TCP
```

Essential:

```text
Yes
```

---

# 32. Create CloudWatch Exporter Service

Service:

```text
cloudwatch-exporter-service
```

Task definition:

```text
monitoring-cloudwatch-exporter
```

Desired count:

```text
1
```

Launch:

```text
Fargate
```

Public IP:

```text
OFF
```

No ALB is required.

---

# 33. CloudWatch Exporter Networking

CloudWatch Exporter must be reachable by Prometheus.

Recommended:

```text
Prometheus
    |
    | TCP 9106
    v
CloudWatch Exporter
```

Use ECS Service Connect or ECS Cloud Map/service discovery.

Example service name:

```text
cloudwatch-exporter
```

Port:

```text
9106
```

Prometheus can then use:

```text
cloudwatch-exporter:9106
```

---

# 34. Prometheus Configuration

Example:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:

  - job_name: "prometheus"
    static_configs:
      - targets:
          - "localhost:9090"

  - job_name: "cloudwatch-exporter"
    static_configs:
      - targets:
          - "cloudwatch-exporter:9106"
```

The `cloudwatch-exporter` hostname assumes ECS service discovery/Service Connect is configured.

---

# 35. Grafana Prometheus Data Source

Login to:

```text
http://albtest-1244121495.us-east-1.elb.amazonaws.com/grafana/
```

Go to:

```text
Connections
    |
    +-- Data Sources
        |
        +-- Add data source
            |
            +-- Prometheus
```

Use:

```text
http://prometheus:9090
```

Click:

```text
Save & Test
```

---

# 36. Important ECS Service Discovery Note

The hostname:

```text
prometheus:9090
```

inside Grafana will only work if Grafana and Prometheus can resolve each other through:

```text
ECS Service Connect
```

or:

```text
AWS Cloud Map
```

Do not assume that ECS service names automatically provide DNS resolution.

---

# 37. Final URLs

Frontend:

```text
http://albtest-1244121495.us-east-1.elb.amazonaws.com/
```

Grafana:

```text
http://albtest-1244121495.us-east-1.elb.amazonaws.com/grafana/
```

Prometheus:

```text
http://albtest-1244121495.us-east-1.elb.amazonaws.com/prometheus/
```

CloudWatch Exporter:

```text
Private ECS Service
```

It should NOT be publicly accessible.

---

# 38. Test Grafana

Open:

```text
http://albtest-1244121495.us-east-1.elb.amazonaws.com/grafana/
```

Login:

```text
Username:
admin

Password:
admin
```

---

# 39. Test Prometheus

Open:

```text
http://albtest-1244121495.us-east-1.elb.amazonaws.com/prometheus/
```

Go to:

```text
Status
    |
    +-- Targets
```

Expected:

```text
cloudwatch-exporter
UP
```

---

# 40. Test CloudWatch Exporter

CloudWatch Exporter is private.

Do not use:

```text
http://ALB:9106
```

Instead check the ECS task using ECS Exec if enabled:

```bash
aws ecs execute-command \
  --cluster testcluster \
  --task TASK_ID \
  --container cloudwatch-exporter \
  --interactive \
  --command "/bin/sh"
```

Then:

```bash
curl http://localhost:9106/metrics
```

---

# 41. Target Group Health

Check:

```text
EC2
    |
    +-- Target Groups
```

Grafana:

```text
grafana-tg
```

Expected:

```text
Healthy
```

Prometheus:

```text
prometheus-tg
```

Expected:

```text
Healthy
```

---

# 42. Grafana Health Check

Target group:

```text
grafana-tg
```

Path:

```text
/api/health
```

Expected:

```text
HTTP 200
```

---

# 43. Prometheus Health Check

Target group:

```text
prometheus-tg
```

Path:

```text
/-/healthy
```

Expected:

```text
HTTP 200
```

---

# 44. ECS CloudWatch Logs

Configure the containers to use the AWS logs driver.

Recommended log groups:

```text
/ecs/frontend

/ecs/backend

/ecs/grafana

/ecs/prometheus

/ecs/cloudwatch-exporter
```

Region:

```text
us-east-1
```

---

# 45. EFS Persistence

For production monitoring, use Amazon EFS.

Recommended directories:

```text
EFS
 |
 +-- prometheus/
 |
 +-- grafana/
```

Prometheus mount:

```text
/prometheus
```

Grafana mount:

```text
/var/lib/grafana
```

Do not rely on Fargate ephemeral storage for important monitoring data.

---

# 46. Production HTTPS

The current testing setup uses:

```text
HTTP
```

For production use:

```text
HTTPS :443
```

Recommended architecture:

```text
Internet
   |
   v
HTTPS :443
   |
   v
ALB
   |
   +-- /grafana
   |
   +-- /prometheus
   |
   +-- /
```

Use AWS Certificate Manager for the certificate.

---

# 47. Production Grafana Password

Do not use:

```text
GF_SECURITY_ADMIN_PASSWORD=admin
```

in production.

Use:

```text
AWS Secrets Manager
```

and inject the password into the ECS task.

---

# 48. ECS Deployment Workflow

The complete deployment process is:

```text
Developer
    |
    v
Docker Compose
    |
    v
Build 5 Docker Images
    |
    v
ECR
    |
    +------------------+
    |                  |
    v                  v
ECS Fargate       Existing ALB
    |                  |
    |          +-------+-------+
    |          |               |
    |          v               v
    |       /grafana      /prometheus
    |          |               |
    |          v               v
    |       Grafana        Prometheus
    |                          |
    |                          v
    |                  CloudWatch Exporter
    |                          |
    |                          v
    |                    AWS CloudWatch
    |
    +-- Frontend
    |
    +-- Backend
```

---

# 49. ECR Build and Push

Run:

```bash
./ecr-tag-push.sh
```

The script performs:

```text
docker compose build
        |
        +-- frontend
        +-- backend
        +-- grafana
        +-- prometheus
        +-- cloudwatch-exporter
        |
        v
docker tag
        |
        v
docker push
        |
        v
ECR
```

---

# 50. ECS Deployment Checklist

## ECR

- [ ] ecomm-frontend repository
- [ ] ecomm-backend repository
- [ ] monitoring-grafana repository
- [ ] monitoring-prometheus repository
- [ ] monitoring-cloudwatch-exporter repository
- [ ] All images pushed

## IAM

- [ ] ecsTaskExecutionRole exists
- [ ] AmazonECSTaskExecutionRolePolicy attached
- [ ] ecsCloudWatchExporterTaskRole created
- [ ] CloudWatch read permissions configured

## ECS

- [ ] Existing `testcluster` selected
- [ ] Grafana task definition created
- [ ] Prometheus task definition created
- [ ] CloudWatch Exporter task definition created
- [ ] Grafana service created
- [ ] Prometheus service created
- [ ] CloudWatch Exporter service created

## Networking

- [ ] Same VPC
- [ ] Correct subnets
- [ ] Public IP disabled
- [ ] ECS security group configured
- [ ] ALB security group configured
- [ ] Prometheus can reach CloudWatch Exporter
- [ ] Grafana can reach Prometheus

## ALB

- [ ] Existing ALB reused
- [ ] Existing frontend rule unchanged
- [ ] Existing backend rule unchanged
- [ ] `grafana-tg` created
- [ ] `prometheus-tg` created
- [ ] `/grafana*` rule created
- [ ] `/prometheus*` rule created

## Health

- [ ] Grafana target healthy
- [ ] Prometheus target healthy
- [ ] Grafana `/api/health` returns 200
- [ ] Prometheus `/-/healthy` returns 200
- [ ] Prometheus target is UP
- [ ] CloudWatch Exporter returns metrics

## Grafana

- [ ] Grafana accessible
- [ ] Prometheus data source configured
- [ ] Prometheus data source Save & Test successful

---

# 51. Final Port Reference

| Service | Container Port | ALB |
|---|---:|---|
| Frontend | 80 | Yes |
| Backend | 5000 | Existing |
| Grafana | 3000 | `/grafana*` |
| Prometheus | 9090 | `/prometheus*` |
| CloudWatch Exporter | 9106 | No |

---

# 52. Final URLs

```text
Frontend
http://albtest-1244121495.us-east-1.elb.amazonaws.com/
```

```text
Grafana
http://albtest-1244121495.us-east-1.elb.amazonaws.com/grafana/
```

```text
Prometheus
http://albtest-1244121495.us-east-1.elb.amazonaws.com/prometheus/
```

```text
CloudWatch Exporter
Private ECS service only
```

---

# 53. Important Security Rules

Never expose CloudWatch Exporter publicly.

Never expose Prometheus directly to:

```text
0.0.0.0/0
```

Never put AWS access keys into:

```text
.env
docker-compose.yml
Dockerfile
config.yml
```

Use:

```text
EC2 IAM Role
```

for EC2.

Use:

```text
ECS Task IAM Role
```

for ECS.

Use:

```text
AWS Secrets Manager
```

for passwords and secrets.

---

# 54. Recommended Production Image Tags

For testing:

```text
:latest
```

is acceptable.

For production, use versioned tags:

```text
:v1
:v2
:v3
```

Example:

```text
monitoring-grafana:v1
monitoring-prometheus:v1
monitoring-cloudwatch-exporter:v1
```

This makes ECS deployments and rollbacks easier.

---

# 55. EC2 to ECS Migration

Phase 1:

```text
EC2
 |
 +-- Docker Compose
       |
       +-- Frontend
       +-- Backend
       +-- Grafana
       +-- Prometheus
       +-- CloudWatch Exporter
```

Test everything.

Then:

```bash
./ecr-tag-push.sh
```

Phase 2:

```text
ECR
 |
 +-- Frontend
 +-- Backend
 +-- Grafana
 +-- Prometheus
 +-- CloudWatch Exporter
       |
       v
ECS Fargate
       |
       v
Existing ALB
```

---

# 56. Final Production Architecture

```text
                           INTERNET
                              |
                              v
                       Application ALB
                              |
                    HTTPS :443 recommended
                              |
          +-------------------+-------------------+
          |                   |                   |
          v                   v                   v
       Frontend            /grafana          /prometheus
          |                   |                   |
          v                   v                   v
     Frontend ECS        Grafana ECS        Prometheus ECS
                                                  |
                                                  |
                                                  v
                                      CloudWatch Exporter ECS
                                                  |
                                                  v
                                           AWS CloudWatch


Existing Backend:

ALB
 |
 +-- Backend Target Group
       |
       v
   Backend ECS
       |
       v
   Backend :5000
```

---

# 57. Deployment Complete

The final system contains:

```text
APPLICATION
├── Frontend
└── Backend

MONITORING
├── Grafana
├── Prometheus
└── CloudWatch Exporter

AWS
├── ECR
├── ECS Fargate
├── ALB
├── IAM
├── CloudWatch
└── EFS (recommended for persistence)
```

The existing ALB is reused and monitoring is exposed through:

```text
/grafana
/prometheus
```

while CloudWatch Exporter remains private.

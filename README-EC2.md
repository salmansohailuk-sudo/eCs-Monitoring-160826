# EC2 Deployment Guide
# E-Commerce + Monitoring Stack

This guide deploys the complete application and monitoring stack on an EC2 instance using Docker Compose.

## Stack

- Frontend
- Backend
- Grafana
- Prometheus
- CloudWatch Exporter

The same Docker images can later be pushed to Amazon ECR and deployed to ECS Fargate.

---

# 1. Architecture

```text
                         EC2 INSTANCE
                              |
                         Docker Compose
                              |
       +----------------------+----------------------+
       |                      |                      |
       v                      v                      v
  Application            Monitoring             Monitoring
       |                      |                      |
       v                      v                      v
   Frontend              Grafana              CloudWatch
     :80                   :3000                Exporter
       |                      |                    :9106
       v                      v                      |
    Backend              Prometheus               |
      :5000                  :9090                 |
                              |                    |
                              +--------------------+
                                       |
                                       v
                                AWS CloudWatch
```

---

# 2. Project Directory

The final project structure should look like:

```text
project/
│
├── docker-compose.yml
├── .env
├── create-directories.sh
├── ecr-tag-push.sh
├── README-EC2.md
├── README-ECS.md
│
├── frontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   └── ...
│
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── app.py
│   └── ...
│
└── monitoring/
    │
    ├── grafana/
    │   └── Dockerfile
    │
    ├── prometheus/
    │   ├── Dockerfile
    │   └── prometheus.yml
    │
    └── cloudwatch-exporter/
        ├── Dockerfile
        └── config.yml
```

---

# 3. Required Software

Install the following on the EC2 instance:

```text
Docker
Docker Compose
Git
AWS CLI
```

Check installations:

```bash
docker --version
docker compose version
git --version
aws --version
```

---

# 4. Clone Project

Clone your repository:

```bash
git clone YOUR_GITHUB_REPOSITORY_URL
```

Enter the project:

```bash
cd YOUR_PROJECT_DIRECTORY
```

---

# 5. Create Directories

Make the script executable:

```bash
chmod +x create-directories.sh
```

Run:

```bash
./create-directories.sh
```

Check:

```bash
tree .
```

If `tree` is not installed:

```bash
find . -maxdepth 3 -type f | sort
```

---

# 6. Docker Compose

The root `docker-compose.yml` builds all five services.

```yaml
version: "3.9"

services:

  frontend:
    image: ecomm-frontend:latest
    build:
      context: ./frontend
    ports:
      - "80:80"
    depends_on:
      - backend

  backend:
    image: ecomm-backend:latest
    build:
      context: ./backend
    env_file:
      - .env
    ports:
      - "5000:5000"

  grafana:
    image: monitoring-grafana:latest
    build:
      context: ./monitoring/grafana
    ports:
      - "3000:3000"
    environment:
      GF_SECURITY_ADMIN_USER: admin
      GF_SECURITY_ADMIN_PASSWORD: admin
      GF_SERVER_ROOT_URL: http://localhost:3000/
      GF_SERVER_SERVE_FROM_SUB_PATH: "true"
    depends_on:
      - prometheus

  prometheus:
    image: monitoring-prometheus:latest
    build:
      context: ./monitoring/prometheus
    ports:
      - "9090:9090"
    depends_on:
      - cloudwatch-exporter

  cloudwatch-exporter:
    image: monitoring-cloudwatch-exporter:latest
    build:
      context: ./monitoring/cloudwatch-exporter
    ports:
      - "9106:9106"
```

---

# 7. Build All Docker Images

From the project root:

```bash
docker compose build
```

For a completely clean build:

```bash
docker compose build --no-cache
```

Check images:

```bash
docker images
```

Expected images:

```text
ecomm-frontend
ecomm-backend
monitoring-grafana
monitoring-prometheus
monitoring-cloudwatch-exporter
```

---

# 8. Start All Containers

Run:

```bash
docker compose up -d
```

Check:

```bash
docker compose ps
```

Expected:

```text
frontend
backend
grafana
prometheus
cloudwatch-exporter
```

All containers should show:

```text
Up
```

---

# 9. Check Docker Containers

```bash
docker ps
```

Expected ports:

```text
Frontend              80
Backend              5000
Grafana              3000
Prometheus           9090
CloudWatch Exporter  9106
```

---

# 10. View Logs

All services:

```bash
docker compose logs
```

Follow logs:

```bash
docker compose logs -f
```

Grafana:

```bash
docker compose logs -f grafana
```

Prometheus:

```bash
docker compose logs -f prometheus
```

CloudWatch Exporter:

```bash
docker compose logs -f cloudwatch-exporter
```

Backend:

```bash
docker compose logs -f backend
```

Frontend:

```bash
docker compose logs -f frontend
```

---

# 11. EC2 Security Group

For testing, allow:

```text
TCP 80
TCP 3000
TCP 9090
```

Prefer allowing access from your own IP address.

Do NOT expose:

```text
TCP 9106
```

to the public Internet.

Backend port `5000` should also only be exposed if required for testing.

---

# 12. Test Frontend

Open:

```text
http://EC2_PUBLIC_IP/
```

Example:

```text
http://54.x.x.x/
```

---

# 13. Test Backend

Open your backend API:

```text
http://EC2_PUBLIC_IP:5000/
```

Use the appropriate API endpoint for your application.

---

# 14. Test Grafana

Open:

```text
http://EC2_PUBLIC_IP:3000/
```

Default credentials:

```text
Username: admin
Password: admin
```

Change the password for production.

---

# 15. Test Prometheus

Open:

```text
http://EC2_PUBLIC_IP:9090/
```

Go to:

```text
Status
    |
    +-- Targets
```

Check that targets are:

```text
UP
```

---

# 16. Test CloudWatch Exporter

From the EC2 instance:

```bash
curl http://localhost:9106/metrics
```

You should receive Prometheus metrics.

Example:

```text
# HELP ...
# TYPE ...
```

---

# 17. EC2 IAM Role

CloudWatch Exporter needs AWS permissions.

The recommended solution is to attach an IAM role to the EC2 instance.

Do NOT put AWS access keys inside:

```text
.env
docker-compose.yml
Dockerfile
config.yml
```

---

# 18. CloudWatch IAM Policy

The EC2 IAM role should have permissions similar to:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics"
      ],
      "Resource": "*"
    }
  ]
}
```

Use the minimum permissions required for your actual CloudWatch configuration.

---

# 19. Prometheus Configuration

Example:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:

  - job_name: "prometheus"
    static_configs:
      - targets:
          - "prometheus:9090"

  - job_name: "cloudwatch-exporter"
    static_configs:
      - targets:
          - "cloudwatch-exporter:9106"
```

Docker Compose provides internal DNS.

Therefore:

```text
prometheus:9090
```

and:

```text
cloudwatch-exporter:9106
```

can be used between containers.

---

# 20. Grafana Prometheus Data Source

Login to Grafana.

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

Prometheus URL:

```text
http://prometheus:9090
```

Click:

```text
Save & Test
```

---

# 21. Useful Prometheus Queries

Check targets:

```promql
up
```

CloudWatch ECS CPU:

```promql
aws_ecs_cpuutilization_average
```

Application Load Balancer request count:

```promql
aws_applicationelb_request_count_sum
```

---

# 22. Restart a Service

Grafana:

```bash
docker compose restart grafana
```

Prometheus:

```bash
docker compose restart prometheus
```

CloudWatch Exporter:

```bash
docker compose restart cloudwatch-exporter
```

---

# 23. Rebuild a Service

Grafana:

```bash
docker compose build grafana
docker compose up -d grafana
```

Prometheus:

```bash
docker compose build prometheus
docker compose up -d prometheus
```

CloudWatch Exporter:

```bash
docker compose build cloudwatch-exporter
docker compose up -d cloudwatch-exporter
```

---

# 24. Stop Containers

```bash
docker compose down
```

---

# 25. Stop and Remove Volumes

Be careful with this command:

```bash
docker compose down -v
```

This can delete Docker volumes.

Do not use it if you need persistent monitoring data.

---

# 26. Check Ports

```bash
sudo ss -lntp
```

Expected:

```text
80
5000
3000
9090
9106
```

---

# 27. Check Docker

```bash
sudo systemctl status docker
```

Restart Docker if required:

```bash
sudo systemctl restart docker
```

---

# 28. Check Disk Space

```bash
df -h
```

Check Docker disk usage:

```bash
docker system df
```

---

# 29. Clean Unused Docker Resources

```bash
docker system prune
```

Do not use:

```bash
docker system prune -a
```

unless you understand that unused images may be deleted.

---

# 30. Build and Push to ECR

Once EC2 testing is successful:

```bash
chmod +x ecr-tag-push.sh
```

Run:

```bash
./ecr-tag-push.sh
```

The script will:

1. Login to ECR
2. Build all five images
3. Tag all five images
4. Push all five images

---

# 31. ECR Repositories

The following ECR repositories are required:

```text
ecomm-frontend

ecomm-backend

monitoring-grafana

monitoring-prometheus

monitoring-cloudwatch-exporter
```

---

# 32. ECR Images

The final images will be:

```text
ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ecomm-frontend:latest

ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ecomm-backend:latest

ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/monitoring-grafana:latest

ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/monitoring-prometheus:latest

ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/monitoring-cloudwatch-exporter:latest
```

---

# 33. EC2 Testing Checklist

- [ ] Docker installed
- [ ] Docker Compose installed
- [ ] AWS CLI installed
- [ ] EC2 IAM role configured
- [ ] Project cloned
- [ ] Directories created
- [ ] Frontend Dockerfile exists
- [ ] Backend Dockerfile exists
- [ ] Grafana Dockerfile exists
- [ ] Prometheus Dockerfile exists
- [ ] CloudWatch Exporter Dockerfile exists
- [ ] Docker Compose builds successfully
- [ ] All containers start
- [ ] Frontend works
- [ ] Backend works
- [ ] Grafana works
- [ ] Prometheus works
- [ ] CloudWatch Exporter returns metrics
- [ ] Prometheus scrapes CloudWatch Exporter
- [ ] Grafana connects to Prometheus
- [ ] ECR push succeeds

---

# 34. EC2 Ports

| Service | Port |
|---|---:|
| Frontend | 80 |
| Backend | 5000 |
| Grafana | 3000 |
| Prometheus | 9090 |
| CloudWatch Exporter | 9106 |

CloudWatch Exporter should remain private.
# Monitoring Stack Review — CloudWatch Exporter & Nginx Exporter

This documents the review of the EC2 + Docker Compose monitoring stack
(Prometheus, Grafana, CloudWatch Exporter, Nginx Exporter) and the changes
made to `docker-compose.yml`, `frontend/default.conf`, and the Terraform
files (`ec2.tf`, `security-groups.tf`, `variables.tf`).

## 1. What was already correctly wired

Before touching anything, both exporters were already "baked in":

- `docker-compose.yml` builds and runs `nginx-exporter` and
  `cloudwatch-exporter` as services on the shared `ecommerce-network`.
- `monitoring/prometheus/prometheus.yml` already scrapes all four targets:
  `prometheus:9090`, `cloudwatch-exporter:9106`, `backend:5000`, and
  `nginx-exporter:9113`.
- `frontend/default.conf` already exposes an nginx `stub_status` endpoint
  at `/nginx_status` for the exporter to scrape via
  `NGINX_SCRAPE_URI=http://frontend/nginx_status`.
- `backend/app.py` already exposes a native `/metrics` endpoint via
  `prometheus_client`.
- The EC2 IAM role/instance profile already grants
  `cloudwatch:GetMetricData` / `GetMetricStatistics` / `ListMetrics`.

So the wiring was sound; the gaps were in things that don't show up until
the stack is actually running on EC2.

## 2. Fixes applied

### 2.1 CRITICAL — IMDS hop limit blocks the CloudWatch exporter's credentials
**File:** `ec2.tf`

The CloudWatch exporter has no AWS keys anywhere (correctly) — it relies on
the EC2 instance profile via the Instance Metadata Service (IMDS) at
`169.254.169.254`. By default, AWS sets
`http_put_response_hop_limit = 1` on new instances, which is only enough
for processes running directly on the host to reach IMDS. A container
reached through the Docker bridge network is one extra network hop away,
so with the default limit the CloudWatch exporter's SDK credential lookup
times out. The symptom is usually a container that starts fine but
`/metrics` returns no `aws_*` series, or logs showing repeated
`com.amazonaws.SdkClientException` / credential timeouts.

Added:
```hcl
metadata_options {
  http_endpoint               = "enabled"
  http_tokens                 = "required"
  http_put_response_hop_limit = 2
}
```
This keeps IMDSv2 required (more secure than the "optional" default) while
letting the extra Docker network hop reach the metadata service.

### 2.2 Nginx `/nginx_status` was exposed to the whole internet
**File:** `frontend/default.conf`

The `stub_status` location had `allow all;`, and it lives on the same
public `listen 80` server block as the storefront. Combined with the
security group allowing `0.0.0.0/0` on port 80, this meant anyone on the
internet could hit `http://<ec2-ip>/nginx_status` and see internal nginx
connection stats — not sensitive data here, but it's an unauthenticated
information leak and generally bad practice to expose scrape endpoints
publicly.

Changed to only allow the Docker network ranges (and localhost), denying
everyone else:
```nginx
location = /nginx_status {
    stub_status;
    access_log off;
    allow 172.16.0.0/12;
    allow 192.168.0.0/16;
    allow 127.0.0.1;
    deny all;
}
```
The `nginx-exporter` container still reaches it fine (same compose
network); external clients now get a 403.

### 2.3 No restart policy — a container crash or EC2 reboot doesn't self-heal
**File:** `docker-compose.yml`

None of the six services had a `restart` policy, so if the EC2 instance
rebooted (patching, stop/start, spot interruption if ever moved to spot)
or a container crashed, nothing would come back up on its own — a manual
SSH + `docker compose up -d` was implicitly required. Added
`restart: unless-stopped` to every service.

### 2.4 No data persistence for Prometheus/Grafana
**File:** `docker-compose.yml`

Prometheus stores its TSDB at `/prometheus` and Grafana stores its SQLite
DB/dashboards state at `/var/lib/grafana`, both inside the container
filesystem. Any `docker compose up -d --build` (e.g. after a `git pull`)
recreates these containers and silently wipes metric history and any
manually-added Grafana changes (API keys, alert rules, UI-added
dashboards). Added named volumes:
```yaml
volumes:
  - prometheus_data:/prometheus     # prometheus service
  - grafana_data:/var/lib/grafana   # grafana service
```
This is additive and doesn't change any existing paths/ports, so it won't
break the current deployment — on the next `docker compose up -d` these
volumes are created fresh (existing history isn't retroactively restored,
but from that point on it survives rebuilds).

### 2.5 Admin/monitoring ports open to 0.0.0.0/0
**Files:** `variables.tf`, `security-groups.tf`

SSH (22), Prometheus (9090), CloudWatch exporter (9106), and Nginx
exporter (9113) were all open to the entire internet. These aren't the
public storefront (port 80) — they're operational surfaces that ideally
only you or your VPN/office IP should reach. Introduced
`var.admin_cidr_blocks` (defaults to `["0.0.0.0/0"]`, so **behavior is
unchanged** until you set it) and pointed those four ingress rules at it.
To lock it down, set in a `terraform.tfvars` (already gitignored):
```hcl
admin_cidr_blocks = ["203.0.113.4/32"]
```

## 3. Recommended, not yet applied

These are worth doing but are either environment-specific, higher-risk to
apply blindly, or out of scope for "don't break the current working
deploy" — flagging them for a deliberate follow-up:

- **Secrets are hardcoded in `variables.tf` and committed `.env`**: DB
  password, Stripe test keys, Grafana admin password, and the GitHub PAT
  all live as plaintext defaults in version control. `*.tfvars` is already
  gitignored — move real values into a `terraform.tfvars` (never
  committed) or AWS Secrets Manager / SSM Parameter Store, and stop
  committing `.env` with real values (keep an `.env.example` instead).
- **Rotate the GitHub token that was shared in this conversation.** Any
  token pasted into a chat should be treated as compromised — revoke it
  in GitHub Settings → Developer settings → Personal access tokens and
  issue a new one.
- **Pin image tags instead of `:latest`** for `prom/prometheus`,
  `prom/cloudwatch-exporter`, and `grafana/grafana` base images (the
  nginx exporter is already pinned to `1.4.2`, which is good practice) —
  `:latest` means a `docker compose build --no-cache` next month can pull
  in breaking changes without warning.
- **Add container healthchecks** for `backend` and `prometheus` so
  `depends_on` can use `condition: service_healthy` instead of just
  "container started." The nginx-exporter and cloudwatch-exporter base
  images are minimal (no shell/curl), so a straightforward
  `test: ["CMD", "curl", ...]` won't work there without a custom
  healthcheck binary — left out to avoid breaking startup.
- **CPU/memory limits** (`deploy.resources.limits` or `mem_limit`/
  `cpus`) on each service so one runaway container (e.g. Prometheus TSDB
  growth) can't starve the whole `t3.small` instance.
- **Log rotation**: set `logging.driver: json-file` with `max-size`/
  `max-file` options; without it, container logs can fill the EC2 root
  volume over time.
- **Prometheus retention flags** (`--storage.tsdb.retention.time=15d`) to
  bound disk usage now that data persists in a volume.
- **Alerting**: no Alertmanager is deployed; Prometheus can currently
  detect problems but nothing pages/notifies on them.

## 4. Files changed

| File | Change |
|---|---|
| `docker-compose.yml` | Added `restart: unless-stopped` to all 6 services; added `prometheus_data`/`grafana_data` named volumes; added `AWS_REGION` env to cloudwatch-exporter |
| `frontend/default.conf` | Restricted `/nginx_status` to internal/Docker network ranges |
| `ec2.tf` | Added `metadata_options` block (IMDS hop limit fix) |
| `variables.tf` | Added `admin_cidr_blocks` variable |
| `security-groups.tf` | Ports 22/9090/9106/9113 now use `var.admin_cidr_blocks` instead of hardcoded `0.0.0.0/0` |

No service names, ports, image names, or the overall file layout were
changed — the existing working deploy path (`docker-compose up -d`) is
unaffected.

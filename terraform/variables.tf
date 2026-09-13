# ---------------------------------------------------------
# Global Variables (Edit these as needed)
# ---------------------------------------------------------

# AWS region
variable "aws_region" {
  default = "us-east-1"
}

# EC2 instance type
variable "ec2_instance_type" {
  default = "t3.small"
}

# No SSH key needed (we use EC2 Instance Connect)
variable "ec2_key_name" {
  default = ""
}

# CIDR(s) allowed to reach admin/monitoring ports (SSH, Prometheus,
# CloudWatch exporter, Nginx exporter). Defaults to open internet to match
# current behavior - recommended improvement: set this to your office/VPN
# CIDR (e.g. ["203.0.113.4/32"]) instead of leaving it wide open.
variable "admin_cidr_blocks" {
  type    = list(string)
  default = ["0.0.0.0/0"]
}

# GitHub token for private repo access
variable "github_token" {
  default = "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"
}

# Private GitHub repo URL
variable "github_repo_url" {
  default = "https://github.com/salmansohailuk-sudo/eCs-Monitoring-160826.git"
}

# Database credentials
variable "db_username" { default = "admin" }
variable "db_password" { default = "Cloud123" }
variable "db_name"     { default = "ecomm" }   # Your DB name
variable "db_port"     { default = 3306 }

# Stripe test keys
variable "stripe_secret_key" {
  default = "sk_test_51TubqqKrKF732rFWVJzlq745qQxqkwSK8nmAxhCYK9wqvZy0kXkhMjdL3g4eGloaXPIKZSOhc6TyCX4afZCIkmcz00iF2oqtxp"
}

variable "stripe_webhook_secret" {
  default = "whsec_s7hNyViJ5ReMP9h6tUgyHmHC1fZuHl1Z"
}

# Grafana admin credentials
variable "grafana_admin_user"     { default = "lokesh" }
variable "grafana_admin_password" { default = "faisal" }

# Cloud Map namespace (used later in ECS project)
variable "cloud_map_namespace" {
  default = "testcluster.local"
}

# Service names (used inside .env)
variable "frontend_service"          { default = "frontend" }
variable "backend_service"           { default = "backend" }
variable "grafana_service"           { default = "grafana" }
variable "prometheus_service"        { default = "prometheus" }
#variable "cloudwatch_exporter_service" { default = "cloudwatch-exporter" }
#variable "nginx_exporter_service"      { default = "nginx-exporter" }

# ECR repositories to create
variable "ecr_repo_names" {
  type = list(string)
  default = [
    "ecomm-frontend",
    "ecomm-backend",
    "monitoring-prometheus",
    "monitoring-grafana",
    #"monitoring-cloudwatch-exporter",
    #"monitoring-nginx-exporter"
  ]
}

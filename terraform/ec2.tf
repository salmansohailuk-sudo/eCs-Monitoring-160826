# ---------------------------------------------------------
# EC2 Instance (runs your monitoring + app stack)
# ---------------------------------------------------------
resource "aws_instance" "ec2" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = var.ec2_instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  # -------------------------------------------------------
  # IMDS hop limit fix (REQUIRED for cloudwatch-exporter)
  # -------------------------------------------------------
  # By default EC2 sets http_put_response_hop_limit = 1, which only lets
  # processes on the host itself reach the instance metadata service.
  # The cloudwatch-exporter container talks to IMDS through the Docker
  # bridge network - that's a second network hop - so with the default
  # hop limit its AWS SDK credential lookup times out and the exporter
  # silently returns no metrics (or fails to start). Raising the hop
  # limit to 2 lets containers reach IMDS while keeping IMDSv2 required.
  
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # -------------------------------------------------------
  # User Data Script (runs on first boot)
  # -------------------------------------------------------
  user_data = <<-EOF
#!/bin/bash
sudo yum update -y

# Install required packages
sudo yum install docker -y
sudo yum install mariadb105-server -y
sudo yum install jq -y
sudo yum install tree -y
sudo yum install git -y
sudo yum install mariadb -y

# Enable & start Docker
sudo systemctl enable docker
sudo systemctl start docker

# Allow ec2-user to run Docker
sudo usermod -aG docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose


# Clone PRIVATE GitHub repo
# su - ec2-user -c "git clone https://${var.github_token}@github.com/salmansohailuk-sudo/eCs-Monitoring-160826.git /home/ec2-user/eCs-Monitoring-160826"

# Clone PRIVATE GitHub repo
su - ec2-user -c "git clone https://${var.github_token}@github.com/salmansohailuk-sudo/eCs-Monitoring-160826.git /home/ec2-user/eCs-Monitoring-160826"

cd /home/ec2-user/eCs-Monitoring-160826

# ---------------------------------------------------------
# Build and push Docker images to ECR (optional)
# ---------------------------------------------------------

# ---------------------------------------------------------
# FIX: Make backend URL script executable (required by Nginx)
# ---------------------------------------------------------
sudo chmod +x /home/ec2-user/eCs-Monitoring-160826/frontend/20-backend-url.sh



cd /home/ec2-user/eCs-Monitoring-160826

# ---------------------------------------------------------
# Fetch REAL EC2 public IP from metadata
# ---------------------------------------------------------
EC2_PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)

# ---------------------------------------------------------
# Create .env file
# ---------------------------------------------------------
cat > .env <<EOT
AWS_REGION=${var.aws_region}
EC2_PUBLIC_IP=$EC2_PUBLIC_IP

DB_HOST=${aws_db_instance.mysql.address}
DB_USER=${var.db_username}
DB_PASSWORD=${var.db_password}
DB_NAME=${var.db_name}
DB_PORT=${var.db_port}

STRIPE_SECRET_KEY=${var.stripe_secret_key}
STRIPE_WEBHOOK_SECRET=${var.stripe_webhook_secret}

GRAFANA_ADMIN_USER=${var.grafana_admin_user}
GRAFANA_ADMIN_PASSWORD=${var.grafana_admin_password}

CLOUD_MAP_NAMESPACE=${var.cloud_map_namespace}

FRONTEND_SERVICE=${var.frontend_service}
BACKEND_SERVICE=${var.backend_service}
GRAFANA_SERVICE=${var.grafana_service}
PROMETHEUS_SERVICE=${var.prometheus_service}

## CLOUDWATCH_EXPORTER_SERVICE=
## NNGINX_EXPORTER_SERVICE=

## Nginx scrape URI (used by Prometheus to scrape metrics from Nginx exporter)
NGINX_SCRAPE_URI=http://frontend/nginx_status

EOT

# ---------------------------------------------------------
# Run SQL schema to create tables
# ---------------------------------------------------------
mysql -h ${aws_db_instance.mysql.address} -u ${var.db_username} -p${var.db_password} ${var.db_name} < /home/ec2-user/eCs-Monitoring-160826/createdatabase.sql


# Fix permissions
chown -R ec2-user:ec2-user /home/ec2-user/eCs-Monitoring-160826

# Start Docker Compose stack
su - ec2-user -c "cd /home/ec2-user/eCs-Monitoring-160826 && docker-compose up -d"
EOF

  tags = { Name = "ecom-ec2-instance" }
}

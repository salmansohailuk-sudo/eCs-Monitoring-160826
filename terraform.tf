terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  default = "us-east-1"
}

# -----------------------------
# VPC
# -----------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

# -----------------------------
# PUBLIC SUBNETS
# -----------------------------
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true
}

# -----------------------------
# PRIVATE SUBNETS (RDS)
# -----------------------------
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "${var.aws_region}a"
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "${var.aws_region}b"
}

# -----------------------------
# INTERNET GATEWAY + ROUTES
# -----------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# -----------------------------
# SECURITY GROUPS
# -----------------------------
resource "aws_security_group" "ec2_sg" {
  name   = "ec2-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9106
    to_port     = 9106
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9113
    to_port     = 9113
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db_sg" {
  name   = "db-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------
# RDS MYSQL (parameter group removed)
# -----------------------------
resource "aws_db_subnet_group" "db_subnets" {
  name       = "db-subnet-group"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]
}

resource "aws_db_instance" "mysql" {
  identifier        = "ecomm-db"
  engine            = "mysql"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  username = "admin"
  password = "Cloud123"
  db_name  = "ecomm"

  publicly_accessible    = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.db_subnets.name

  skip_final_snapshot = true
}

# -----------------------------
# ECR REPOS
# -----------------------------
resource "aws_ecr_repository" "frontend" {
  name = "ecomm-frontend"
}

resource "aws_ecr_repository" "backend" {
  name = "ecomm-backend"
}

resource "aws_ecr_repository" "grafana" {
  name = "monitoring-grafana"
}

resource "aws_ecr_repository" "prometheus" {
  name = "monitoring-prometheus"
}

resource "aws_ecr_repository" "cloudwatch_exporter" {
  name = "monitoring-cloudwatch-exporter"
}

resource "aws_ecr_repository" "nginx_exporter" {
  name = "monitoring-nginx-exporter"
}

# -----------------------------
# IAM ROLE + POLICY FOR EC2
# -----------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ecomm-ec2-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "ec2_monitoring_policy" {
  name        = "ecomm-ec2-monitoring-policy"
  description = "Allows EC2 to read CloudWatch metrics and perform AWS service discovery"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "CloudWatchMetrics"
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2Discovery"
        Effect = "Allow"
        Action = ["ec2:DescribeInstances"]
        Resource = "*"
      },
      {
        Sid    = "ECSDiscovery"
        Effect = "Allow"
        Action = [
          "ecs:ListClusters",
          "ecs:DescribeClusters",
          "ecs:ListServices",
          "ecs:DescribeServices",
          "ecs:ListTasks",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      },
      {
        Sid    = "LoadBalancerDiscovery"
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetHealth"
        ]
        Resource = "*"
      },
      {
        Sid    = "TagDiscovery"
        Effect = "Allow"
        Action = ["tag:GetResources"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_monitoring_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_monitoring_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ecomm-ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# -----------------------------
# EC2 INSTANCE
# -----------------------------
resource "aws_instance" "ec2" {
  ami                         = "ami-0c02fb55956c7d316"
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.ec2_instance_profile.name

  user_data = <<EOF
#!/bin/bash
set -x
exec > /var/log/user-data.log 2>&1

yum update -y

yum install docker -y
yum install mariadb105-server -y
yum install mariadb -y || dnf install mariadb -y
yum install jq -y
yum install tree -y
yum install git -y

systemctl enable docker
systemctl start docker

curl -L "https://github.com/docker/compose/releases/download/v2.29.2/docker-compose-linux-x86_64" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

cd /home/ec2-user
git clone https://github.com/salmansohailuk-sudo/eCs-Monitoring-160826.git ecomm

cd /home/ec2-user/ecomm
chmod 755 frontend/20-backend-url.sh

TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
EC2_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/public-ipv4)

cat > .env <<EOT
FRONTEND_URL=http://$EC2_IP
BACKEND_URL=http://$EC2_IP:5000

DB_HOST=${aws_db_instance.mysql.address}
DB_USER=admin
DB_PASSWORD=Cloud123
DB_NAME=ecomm
DB_PORT=3306

PROMETHEUS_URL=http://$EC2_IP:9090
GRAFANA_URL=http://$EC2_IP:3000
NGINX_EXPORTER_URL=http://$EC2_IP:9113
CLOUDWATCH_EXPORTER_URL=http://$EC2_IP:9106

EC2_PUBLIC_IP=$EC2_IP
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin
NGINX_SCRAPE_URI=http://frontend/nginx_status

STRIPE_SECRET_KEY=sk_test_51TubqqKrKF732rFWVJzlq745qQxqkwSK8nmAxhCYK9wqvZy0kXkhMjdL3g4eGloaXPIKZSOhc6TyCX4afZCIkmcz00iF2oqtxp
STRIPE_WEBHOOK_SECRET=whsec_CXT0ZLFISoic5zKemapnJSqhAvBiwVvc
EOT

mysql -h ${aws_db_instance.mysql.address} -u admin -pCloud123 < createdatabase.sql

docker-compose up -d
EOF

  tags = {
    Name = "ecomm-ec2"
  }
}

# -----------------------------
# OUTPUTS
# -----------------------------
output "ec2_public_ip" {
  value = aws_instance.ec2.public_ip
}

output "db_endpoint" {
  value = aws_db_instance.mysql.address
}

# ---------------------------------------------------------
# EC2 Security Group - Allows app + monitoring + SSH
# ---------------------------------------------------------
resource "aws_security_group" "ec2_sg" {
  name        = "ecom-ec2-sg"
  description = "Allow app + monitoring + SSH"
  vpc_id      = aws_vpc.main.id

  # Frontend (port 80)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Backend (port 5000)
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Grafana (port 3000)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Prometheus (port 9090) - admin/monitoring, not public app traffic
  ingress {
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  # CloudWatch exporter (port 9106) - admin/monitoring, not public app traffic
  ingress {
    from_port   = 9106
    to_port     = 9106
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  # Nginx exporter (port 9113) - admin/monitoring, not public app traffic
  ingress {
    from_port   = 9113
    to_port     = 9113
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  # SSH (port 22) - admin only
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  # Outbound allowed
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecom-ec2-sg"
  }
}

# ---------------------------------------------------------
# RDS Security Group - Only EC2 can access MySQL
# ---------------------------------------------------------
resource "aws_security_group" "rds_sg" {
  name        = "ecom-ec2-rds-sg"
  description = "Allow MySQL from EC2"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ecom-ec2-rds-sg"
  }
}

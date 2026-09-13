# ---------------------------------------------------------
# RDS Subnet Group (uses two private subnets)
# ---------------------------------------------------------
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "ecom-ec2-rds-subnet-group"
  subnet_ids = [aws_subnet.rds_a.id, aws_subnet.rds_b.id]

  tags = { Name = "ecom-ec2-rds-subnet-group" }
}

# ---------------------------------------------------------
# RDS MySQL Database
# ---------------------------------------------------------
resource "aws_db_instance" "mysql" {
  identifier              = "ecom-ec2-db"
  engine                  = "mysql"
  engine_version          = "8.0"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20

  username = var.db_username
  password = var.db_password
  db_name  = var.db_name
  port     = var.db_port

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  publicly_accessible = false
  skip_final_snapshot = true

  tags = { Name = "ecom-ec2-db" }
}

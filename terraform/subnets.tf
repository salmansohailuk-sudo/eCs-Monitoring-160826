# ---------------------------------------------------------
# Public Subnet (EC2 lives here)
# ---------------------------------------------------------
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.20.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"

  tags = { Name = "ecom-ec2-public-subnet" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------
# RDS Subnet A
# ---------------------------------------------------------
resource "aws_subnet" "rds_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.2.0/24"
  availability_zone = "${var.aws_region}a"

  tags = { Name = "ecom-ec2-rds-subnet-a" }
}

# ---------------------------------------------------------
# RDS Subnet B
# ---------------------------------------------------------
resource "aws_subnet" "rds_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.20.3.0/24"
  availability_zone = "${var.aws_region}b"

  tags = { Name = "ecom-ec2-rds-subnet-b" }
}

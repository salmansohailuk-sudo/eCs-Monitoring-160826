# ---------------------------------------------------------
# VPC for EC2 Project (unique name)
# ---------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "ecom-ec2-vpc" }
}

# ---------------------------------------------------------
# Internet Gateway (allows internet access)
# ---------------------------------------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "ecom-ec2-igw" }
}

# ---------------------------------------------------------
# Public Route Table (routes 0.0.0.0/0 to IGW)
# ---------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "ecom-ec2-public-rt" }
}

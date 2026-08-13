# ─────────────────────────────────────────────
# Network Layer — VPC, Subnets, Routing
# ─────────────────────────────────────────────

# Main VPC
resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "Cloud Threat Detection Lab"
  }
}

# Internet Gateway — gives the public subnet internet access
resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = {
    Name = "threat-lab-igw"
  }
}

# Public Subnet — hosts the attacker box
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "project-subnet-public1-us-east-1a"
  }
}

# Private Subnet — hosts the victim server (no public IP)
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.lab.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.availability_zone

  tags = {
    Name = "project-subnet-private1-us-east-1a"
  }
}

# Route table for the public subnet — routes traffic to the internet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = {
    Name = "threat-lab-public-rt"
  }
}

# Associate the public route table with the public subnet
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
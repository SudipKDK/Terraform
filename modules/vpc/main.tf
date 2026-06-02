# Data source for Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# AWS VPC
resource "aws_vpc" "development" {
  cidr_block = var.vpc_cidr
  tags = {
    "Name" = "${var.environment}-vpc"
  }
}

# AWS Subnet - Public
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.development.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    "Name" = "public-subnet-${count.index + 1}"
  }
}

# AWS Subnet - Private
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.development.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    "Name" = "private-subnet-${count.index + 1}"
  }
}

# Internet Gateway (IGW)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.development.id
  tags = {
    "Name" = "main-igw"
  }
}

# AWS Route Table - Public
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.development.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    "Name" = "public-rt"
  }
}

# Route Table Association - Public
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# AWS Route Table - Private
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.development.id
  tags = {
    "Name" = "private-rt"
  }
}

# Route Table Association - Private
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# AWS S3 Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.development.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private.id,
    aws_route_table.public.id
  ]
  tags = {
    "Name" = "s3-gateway-endpoint"
  }
}

# AWS DB Subnet Group
resource "aws_db_subnet_group" "rds" {
  name       = "${var.environment}-rds-subnet-group"
  subnet_ids = aws_subnet.private[*].id
  tags = {
    "Name" = "${var.environment}-rds-subnet-group"
  }
}
# AWS VPC
resource "aws_vpc" "development" {
  cidr_block = "10.0.0.0/16"
  tags = {
    "Name" = "development-vpc"
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

# AWS Security Group - Public
resource "aws_security_group" "public-sg" {
  name        = "public-vm-sg"
  description = "Security group for public facing server"
  vpc_id      = aws_vpc.development.id

  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    "Name" = "public-sg"
  }
}

# AWS Security Group - Private
resource "aws_security_group" "private-sg" {
  name        = "private-vm-sg"
  description = "SG for private instance"
  vpc_id      = aws_vpc.development.id

  ingress {
    description     = "SSH from Public VM"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public-sg.id]
  }
  
  ingress {
    description     = "Allow ICMP packet traffic"
    from_port       = -1
    to_port         = -1
    protocol        = "icmp"
    security_groups = [aws_security_group.public-sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    "Name" = "private-sg"
  }
}

# AWS Key-Pair Management
resource "tls_private_key" "vm_key" {
  algorithm = "ED25519"
}

resource "aws_key_pair" "deployer_key" {
  key_name   = "tf-managed-key"
  public_key = tls_private_key.vm_key.public_key_openssh
}

resource "local_file" "private_key_pem" {
  content         = tls_private_key.vm_key.private_key_openssh
  filename        = "${path.module}/tf-managed-key.pem"
  file_permission = "0600"
}


# AWS Instance - Public
resource "aws_instance" "public_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.public-sg.id]
  key_name               = aws_key_pair.deployer_key.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.labInstanceProfile.name
  
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install nginx -y
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    "Name" = "ubuntu-public-instance"
  }
}

resource "aws_instance" "public_instance_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.public-sg.id]
  key_name               = aws_key_pair.deployer_key.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.labInstanceProfile.name
  
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install nginx -y
              systemctl start nginx
              systemctl enable nginx
              EOF

  tags = {
    "Name" = "ubuntu-public-server"
  }
}

# AWS Instance - Private
resource "aws_instance" "private_instance" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.private-sg.id]
  key_name               = aws_key_pair.deployer_key.key_name
  iam_instance_profile   = data.aws_iam_instance_profile.labInstanceProfile.name
  
  tags = {
    "Name" = "ubuntu-private-vm"
  }
}

# Database Subnet Group
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "main-rds-subnet-group"
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.private[1].id]
  tags = {
    "Name" = "rds-private-subnet-group"
  }
}

# RDS Security Group
resource "aws_security_group" "rds_sg" {
  name        = "rds-postgres-sg"
  description = "Allow DB traffic from VMs"
  vpc_id      = aws_vpc.development.id

  ingress {
    description     = "PostgreSQL from public VM"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.public-sg.id]
  }

  ingress {
    description     = "PostgreSQL from private VM"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.private-sg.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    "Name" = "rds-postgres-sg"
  }
}

# AWS RDS PostgreSQL Instance
resource "aws_db_instance" "postgres_db" {
  identifier                 = "free-tier-postgres"
  engine                     = "postgres"
  engine_version             = "16"
  auto_minor_version_upgrade = true
  instance_class             = "db.t3.micro"
  allocated_storage          = 20
  storage_type               = "gp3"

  db_name                    = "postgre_db"
  username                   = "foo"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = {
    Name = "free-tier-postgres-db"
  }
}
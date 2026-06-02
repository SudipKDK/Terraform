# Isolated Security Group for RDS
resource "aws_security_group" "rds_sg" {
  name        = "${var.environment}-rds-sg"
  description = "Allow inbound PostgreSQL traffic from Web Server"
  vpc_id      = var.vpc_id

  # Strict firewall rule: Only allow connections on 5432 from the Public VM's Security Group
  ingress {
    description = "PostgreSQL from Public Web Server"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.selected.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.environment}-rds-sg" }
}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Free-Tier AWS RDS PostgreSQL Instance
resource "aws_db_instance" "postgres_db" {
  identifier                 = "${var.environment}-postgres"
  engine                     = "postgres"
  engine_version             = "16"
  auto_minor_version_upgrade = true
  instance_class             = "db.t3.micro" 
  allocated_storage          = 20            
  storage_type               = "gp3"

  db_name  = var.database_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  skip_final_snapshot    = true
  publicly_accessible    = false

  tags = { Name = "${var.environment}-postgres-db" }
}
variable "environment" {
  type        = string
  description = "The deployment environment (e.g., dev, prod)"
}

variable "vpc_id" {
  type        = string
  description = "The ID of the VPC where RDS will reside"
}

variable "database_name" {
  type    = string
  default = "wordpress"
}

variable "db_username" {
  type    = string
  default = "dbadmin"
}

variable "db_password" {
  type      = string
  sensitive = true # Marks the password as sensitive in console outputs
}

variable "db_subnet_group_name" {
  type        = string
  description = "The database subnet group name passed from the VPC module"
}
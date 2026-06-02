variable "db_password" {
  type        = string
  description = "Database password passed securely via environment variables"
  sensitive   = true
}
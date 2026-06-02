output "rds_endpoint" {
  value       = aws_db_instance.postgres_db.endpoint
  description = "The connection endpoint for the PostgreSQL database"
}
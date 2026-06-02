output "vpc_id" { value = aws_vpc.development.id }
output "public_subnet_id" { value = aws_subnet.public[0].id }
output "private_subnet_ids" { value = aws_subnet.private[*].id }
output "db_subnet_group_name" {
  value       = aws_db_subnet_group.rds.name
  description = "The name of the RDS database subnet group"
}
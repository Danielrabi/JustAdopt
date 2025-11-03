output "db_endpoint" {
  description = "The connection endpoint for the RDS instance"
  value       = aws_db_instance.main.address
}

output "db_name" {
  description = "The name of the database"
  value       = aws_db_instance.main.db_name
}

output "db_username" {
  description = "Username for the database"
  value       = aws_db_instance.main.username
}

output "db_password_secret_arn" {
  description = "ARN of the AWS secret of the DB password"
  value       = aws_secretsmanager_secret.db_password.arn
}
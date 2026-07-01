output "database_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS credentials and connection URL"
  value       = aws_secretsmanager_secret_version.database_credentials.arn
  sensitive   = true
}

output "instance_identifier" {
  description = "Identifier of the RDS instance"
  value       = aws_db_instance.this.identifier
}

output "database_credentials_secret_arn" {
  description = "ARN of the Secrets Manager secret containing the RDS credentials and connection URL"
  value       = aws_secretsmanager_secret_version.database_credentials.arn
  sensitive   = true
}

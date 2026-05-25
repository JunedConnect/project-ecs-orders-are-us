output "repository_names" {
  description = "ECR repository names created for services"
  value       = [for repo in aws_ecr_repository.service : repo.name]
}

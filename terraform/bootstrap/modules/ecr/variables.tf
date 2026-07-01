variable "environment" {
  description = "Environment name used in resource naming"
  type        = string
}

variable "ecr_services" {
  description = "Set of service names that should each get an ECR repository"
  type        = set(string)
}

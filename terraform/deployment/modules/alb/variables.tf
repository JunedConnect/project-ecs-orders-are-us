variable "certificate_arn" {
  description = "ARN of the ACM certificate for ALB"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "environment" {
  description = "Environment name used in resource naming"
  type        = string
}

variable "vpc_id" {
  description = "ID for the VPC"
  type        = string
}

variable "api_gateway_target_group_health_check_path" {
  description = "Health check path for the api-gateway target group"
  type        = string
}

variable "api_gateway_listener_path_patterns" {
  description = "Path patterns that should route to the api-gateway target group"
  type        = list(string)
}

variable "dashboard_target_group_health_check_path" {
  description = "Health check path for the dashboard target group"
  type        = string
}

variable "dashboard_listener_path_patterns" {
  description = "Path patterns that should route to the dashboard target group"
  type        = list(string)
}

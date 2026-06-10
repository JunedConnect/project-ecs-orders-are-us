variable "environment" {
  description = "Environment name used in resource naming"
  type        = string
}

variable "alb_security_group_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "target_group_arn" {
  description = "Target group ARN for api-gateway service"
  type        = string
}

variable "dashboard_target_group_arn" {
  description = "Target group ARN for dashboard-api service"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for ECS"
  type        = string
}

variable "private-subnet-ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecs_launch_type" {
  description = "Launch type for the ECS service"
  type        = string
}

variable "ecs_platform_version" {
  description = "Platform version for the ECS service"
  type        = string
}

variable "ecs_scheduling_strategy" {
  description = "Scheduling strategy for the ECS service"
  type        = string
}

variable "ecs_task_requires_compatibilities" {
  description = "The compatibility requirements for the ECS task definition (e.g., FARGATE or EC2)"
  type        = list(string)
}

variable "ecs_network_mode" {
  description = "Network mode for ECS task"
  type        = string
}

variable "ecs_task_cpu" {
  description = "CPU used for all ECS task definitions"
  type        = number
}

variable "ecs_task_memory" {
  description = "Memory used for all ECS task definitions"
  type        = number
}

variable "enable_execute_command" {
  description = "Enable ECS Exec for services"
  type        = bool
}

variable "secret_recovery_window_in_days" {
  description = "Number of days Secrets Manager keeps ECS secrets recoverable after deletion"
  type        = number
}

variable "api_gateway_image" {
  description = "API Gateway container image"
  type        = string
}

variable "api_gateway_desired_count" {
  description = "API Gateway desired task count"
  type        = number
}

variable "dashboard_api_image" {
  description = "Dashboard API container image"
  type        = string
}

variable "dashboard_api_desired_count" {
  description = "Dashboard API desired task count"
  type        = number
}

variable "inventory_service_image" {
  description = "Inventory service container image"
  type        = string
}

variable "inventory_service_desired_count" {
  description = "Inventory service desired task count"
  type        = number
}

variable "notification_service_image" {
  description = "Notification service container image"
  type        = string
}

variable "notification_service_desired_count" {
  description = "Notification service desired task count"
  type        = number
}

variable "order_service_image" {
  description = "Order service container image"
  type        = string
}

variable "order_service_desired_count" {
  description = "Order service desired task count"
  type        = number
}

variable "payment_service_image" {
  description = "Payment service container image"
  type        = string
}

variable "payment_service_desired_count" {
  description = "Payment service desired task count"
  type        = number
}

variable "scheduler_image" {
  description = "Scheduler container image"
  type        = string
}

variable "scheduler_desired_count" {
  description = "Scheduler desired task count"
  type        = number
}

variable "shipping_service_image" {
  description = "Shipping service container image"
  type        = string
}

variable "shipping_service_desired_count" {
  description = "Shipping service desired task count"
  type        = number
}

variable "worker_image" {
  description = "Worker container image"
  type        = string
}

variable "worker_desired_count" {
  description = "Worker desired task count"
  type        = number
}

variable "rds_database_credentials_secret_arn" {
  description = "Secrets Manager secret ARN containing the RDS connection URL"
  type        = string
  sensitive   = true
}

variable "elasticache_address" {
  description = "ElastiCache endpoint address"
  type        = string
}

variable "sqs_queue_url" {
  description = "URL of the main SQS queue"
  type        = string
}

variable "sqs_main_queue_arn" {
  description = "ARN of the main SQS queue"
  type        = string
}

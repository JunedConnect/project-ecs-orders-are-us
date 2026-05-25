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
variable "api_gateway_image" {
  description = "API Gateway container image"
  type        = string
}

variable "api_gateway_cpu" {
  description = "API Gateway task CPU"
  type        = number
}

variable "api_gateway_memory" {
  description = "API Gateway task memory"
  type        = number
}

variable "api_gateway_container_port" {
  description = "API Gateway container port"
  type        = number
}

variable "api_gateway_desired_count" {
  description = "API Gateway desired task count"
  type        = number
}

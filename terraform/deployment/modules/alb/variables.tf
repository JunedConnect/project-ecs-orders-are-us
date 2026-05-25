variable "certificate_arn" {
  description = "ARN of the ACM certificate for ALB"
  type        = string
}

variable "public-subnet-ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "environment" {
  description = "Environment name used in resource naming"
  type        = string
}

variable "alb_internal" {
  description = "Whether the ALB is internal or not"
  type        = bool
}

variable "alb_load_balancer_type" {
  description = "Type of the load balancer"
  type        = string
}

variable "listener_port_http" {
  description = "Port for the HTTP listener"
  type        = string
}

variable "listener_protocol_http" {
  description = "Protocol for the HTTP listener"
  type        = string
}

variable "listener_port_https" {
  description = "Port for the HTTPS listener"
  type        = string
}

variable "listener_protocol_https" {
  description = "Protocol for the HTTPS listener"
  type        = string
}

variable "vpc_id" {
  description = "ID for the VPC"
  type        = string
}

variable "target_group_health_check_path" {
  description = "Health check path for the target group"
  type        = string
}

variable "target_group_protocol" {
  description = "Protocol for the target group"
  type        = string
}

variable "target_group_target_type" {
  description = "Target type for the target group"
  type        = string
}

variable "api_gateway_container_port" {
  description = "API Gateway container port"
  type        = number
}


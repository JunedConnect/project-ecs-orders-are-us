variable "environment" {
  description = "Environment name used in resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the ElastiCache security group"
  type        = string
}

variable "ecs_security_group_id" {
  description = "ECS security group allowed to access ElastiCache"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.m4.large"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

variable "parameter_group_name" {
  description = "ElastiCache parameter group name"
  type        = string
  default     = "default.redis7"
}

variable "engine_version" {
  description = "ElastiCache engine version"
  type        = string
  default     = "7.0"
}

variable "log_format" {
  description = "Log format for ElastiCache log delivery"
  type        = string
  default     = "text"
}

variable "log_type" {
  description = "Log type for ElastiCache log delivery"
  type        = string
  default     = "slow-log"
}

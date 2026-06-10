variable "aws-tags" {
  description = "Tags for Resources"
  type        = map(string)
}


# ALB

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


# ECS

variable "ecs_launch_type" {
  description = "Launch type for the ECS service"
  type        = string
  default     = "FARGATE"
}

variable "ecs_platform_version" {
  description = "Platform version for the ECS service"
  type        = string
}

variable "ecs_scheduling_strategy" {
  description = "Scheduling strategy for the ECS service"
  type        = string
  default     = "REPLICA"
}

variable "ecs_task_requires_compatibilities" {
  description = "The compatibility requirements for the ECS task definition (e.g., FARGATE or EC2)"
  type        = list(string)
  default     = ["FARGATE"]
}

variable "ecs_network_mode" {
  description = "Network mode for ECS task"
  type        = string
  default     = "awsvpc"
}

variable "ecs_task_cpu" {
  description = "CPU used for all ECS task definitions"
  type        = number
  default     = 256
}

variable "ecs_task_memory" {
  description = "Memory used for all ECS task definitions"
  type        = number
  default     = 512
}

variable "enable_execute_command" {
  description = "Whether ECS Exec is enabled for ECS services"
  type        = bool
  default     = false
}

variable "api_gateway_image" {
  description = "API Gateway container image"
  type        = string
}

variable "api_gateway_desired_count" {
  description = "API Gateway desired task count"
  type        = number
  default     = 2
}

variable "dashboard_api_image" {
  description = "Dashboard API container image"
  type        = string
}

variable "dashboard_api_desired_count" {
  description = "Dashboard API desired task count"
  type        = number
  default     = 1
}

variable "inventory_service_image" {
  description = "Inventory service container image"
  type        = string
}

variable "inventory_service_desired_count" {
  description = "Inventory service desired task count"
  type        = number
  default     = 1
}

variable "notification_service_image" {
  description = "Notification service container image"
  type        = string
}

variable "notification_service_desired_count" {
  description = "Notification service desired task count"
  type        = number
  default     = 1
}

variable "order_service_image" {
  description = "Order service container image"
  type        = string
}

variable "order_service_desired_count" {
  description = "Order service desired task count"
  type        = number
  default     = 1
}

variable "payment_service_image" {
  description = "Payment service container image"
  type        = string
}

variable "payment_service_desired_count" {
  description = "Payment service desired task count"
  type        = number
  default     = 1
}

variable "scheduler_image" {
  description = "Scheduler container image"
  type        = string
}

variable "scheduler_desired_count" {
  description = "Scheduler desired task count"
  type        = number
  default     = 1
}

variable "shipping_service_image" {
  description = "Shipping service container image"
  type        = string
}

variable "shipping_service_desired_count" {
  description = "Shipping service desired task count"
  type        = number
  default     = 1
}

variable "worker_image" {
  description = "Worker container image"
  type        = string
}

variable "worker_desired_count" {
  description = "Worker desired task count"
  type        = number
  default     = 1
}


# ElastiCache

variable "elasticache_node_type" {
  description = "ElastiCache node type"
  type        = string
  default     = "cache.m4.large"
}

variable "elasticache_num_cache_nodes" {
  description = "Number of ElastiCache cache nodes"
  type        = number
  default     = 1
}

variable "elasticache_parameter_group_name" {
  description = "ElastiCache parameter group name"
  type        = string
  default     = "default.redis7"
}

variable "elasticache_engine_version" {
  description = "ElastiCache engine version"
  type        = string
  default     = "7.1"
}


# RDS

variable "rds_allocated_storage" {
  description = "The allocated storage in gigabytes (GB) for the RDS instance"
  type        = number
  default     = 10
}

variable "rds_engine_version" {
  description = "The version of the database engine to use"
  type        = string
  default     = "16.14"
}

variable "rds_instance_class" {
  description = "The instance class to use for the RDS instance (e.g., db.t3.micro)"
  type        = string
  default     = "db.t3.micro"
}

variable "rds_parameter_group_name" {
  description = "The name of the DB parameter group to associate with this instance"
  type        = string
  default     = "default.postgres16"
}

variable "rds_skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted. If true is specified, no DB snapshot is created. If false is specified, a DB snapshot is created before the DB instance is deleted."
  type        = bool
}

variable "rds_username" {
  description = "RDS Database Username"
  type        = string
}

variable "rds_storage_encrypted" {
  description = "Whether RDS storage should be encrypted"
  type        = bool
  default     = true
}

variable "rds_multi_az" {
  description = "Whether RDS should be deployed Multi-AZ"
  type        = bool
}


# Route53

variable "route53_domain_name" {
  description = "The Route53 delegated subdomain name"
  type        = string
}

variable "validation_method" {
  description = "The validation method for the ACM certificate"
  type        = string
  default     = "DNS"
}

variable "dns_ttl" {
  description = "Time to live (TTL) for DNS records"
  type        = number
  default     = 60
}


# SQS

variable "sqs_main_queue_delay_seconds" {
  description = "Delay in seconds for the main SQS queue"
  type        = number
  default     = 0
}

variable "sqs_main_queue_max_message_size" {
  description = "Maximum message size in bytes for the main SQS queue"
  type        = number
  default     = 262144
}

variable "sqs_main_queue_message_retention_seconds" {
  description = "Message retention period in seconds for the main SQS queue"
  type        = number
  default     = 345600
}

variable "sqs_main_queue_receive_wait_time_seconds" {
  description = "Receive wait time in seconds for the main SQS queue"
  type        = number
  default     = 0
}

variable "sqs_max_receive_count" {
  description = "Maximum receives before moving a message to the dead-letter queue"
  type        = number
  default     = 4
}


# VPC

variable "vpc-cidr-block" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.2.0.0/16"
}

variable "publicsubnet1-cidr-block" {
  description = "CIDR block for public subnet 1"
  type        = string
  default     = "10.2.1.0/24"
}

variable "publicsubnet2-cidr-block" {
  description = "CIDR block for public subnet 2"
  type        = string
  default     = "10.2.2.0/24"
}

variable "privatesubnet1-cidr-block" {
  description = "CIDR block for private subnet 1"
  type        = string
  default     = "10.2.3.0/24"
}

variable "privatesubnet2-cidr-block" {
  description = "CIDR block for private subnet 2"
  type        = string
  default     = "10.2.4.0/24"
}

variable "enable-dns-support" {
  description = "Enable DNS support in the VPC"
  type        = bool
  default     = true
}

variable "enable-dns-hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "subnet-map-public-ip-on-launch" {
  description = "Whether to map public IP on launch for subnets"
  type        = bool
  default     = true
}

variable "availability-zone-1" {
  description = "Availability zone 1"
  type        = string
  default     = "eu-west-2a"
}

variable "availability-zone-2" {
  description = "Availability zone 2"
  type        = string
  default     = "eu-west-2b"
}

variable "route-cidr-block" {
  description = "CIDR block for the route"
  type        = string
  default     = "0.0.0.0/0"
}


# WAF

variable "waf_cloudwatch_metrics_enabled" {
  description = "Whether CloudWatch metrics are enabled for WAF visibility config"
  type        = bool
  default     = true
}

variable "waf_sampled_requests_enabled" {
  description = "Whether sampled requests are enabled for WAF visibility config"
  type        = bool
  default     = true
}

variable "waf_metric_name" {
  description = "Metric name for WAF visibility config"
  type        = string
}

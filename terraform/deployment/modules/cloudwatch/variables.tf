variable "environment" {
  description = "Environment name used in resource naming"
  type        = string
}

variable "sqs_queue_name" {
  description = "Name of the SQS queue for CloudWatch dimensions"
  type        = string
}

variable "rds_instance_identifier" {
  description = "RDS instance identifier for CloudWatch dimensions"
  type        = string
}

variable "rds_allocated_storage" {
  description = "Allocated RDS storage in GB, used to calculate the free storage alarm threshold"
  type        = number
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for CloudWatch dimensions"
  type        = string
}

variable "cloudwatch_alarm_email_endpoint" {
  description = "Email address subscribed to CloudWatch alarm SNS notifications"
  type        = string
}

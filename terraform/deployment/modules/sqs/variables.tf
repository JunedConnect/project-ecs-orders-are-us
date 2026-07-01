variable "environment" {
  description = "Environment name used in resource naming"
  type        = string
}

variable "main_queue_delay_seconds" {
  description = "Delay in seconds for the main SQS queue"
  type        = number
}

variable "main_queue_max_message_size" {
  description = "Maximum message size in bytes for the main SQS queue"
  type        = number
}

variable "main_queue_message_retention_seconds" {
  description = "Message retention period in seconds for the main SQS queue"
  type        = number
}

variable "main_queue_receive_wait_time_seconds" {
  description = "Receive wait time in seconds for the main SQS queue"
  type        = number
}

variable "max_receive_count" {
  description = "Maximum receives before moving a message to the dead-letter queue"
  type        = number
}

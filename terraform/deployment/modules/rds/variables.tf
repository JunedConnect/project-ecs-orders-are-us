variable "environment" {
  description = "Environment name used in resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the RDS security group"
  type        = string
}

variable "ecs_security_group_id" {
  description = "ECS security group allowed to access RDS"
  type        = string
}

variable "private-subnet-ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "allocated_storage" {
  description = "The allocated storage in gigabytes (GB) for the RDS instance"
  type        = number
}

variable "engine_version" {
  description = "The version of the database engine to use"
  type        = string
}

variable "instance_class" {
  description = "The instance class to use for the RDS instance (e.g., db.t3.micro)"
  type        = string
}

variable "parameter_group_name" {
  description = "The name of the DB parameter group to associate with this instance"
  type        = string
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted. If true is specified, no DB snapshot is created. If false is specified, a DB snapshot is created before the DB instance is deleted."
  type        = bool
}

variable "db_username" {
  description = "Username for the RDS instance"
  type        = string
}

variable "storage_encrypted" {
  description = "Whether storage for RDS should be encrypted"
  type        = bool
  default     = true
}

variable "multi_az" {
  description = "Whether the RDS instance should be deployed Multi-AZ"
  type        = bool
}

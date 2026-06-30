variable "environment" {
  description = "Environment name used in resource naming"
  type        = string
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "publicsubnet1_cidr_block" {
  description = "CIDR block for public subnet 1"
  type        = string
}

variable "publicsubnet2_cidr_block" {
  description = "CIDR block for public subnet 2"
  type        = string
}

variable "privatesubnet1_cidr_block" {
  description = "CIDR block for private subnet 1"
  type        = string
}

variable "privatesubnet2_cidr_block" {
  description = "CIDR block for private subnet 2"
  type        = string
}

variable "enable_dns_support" {
  description = "Enable DNS support in the VPC"
  type        = bool
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
}

variable "subnet_map_public_ip_on_launch" {
  description = "Whether to map public IP on launch for subnets"
  type        = bool
}

variable "availability_zone_1" {
  description = "Availability zone 1"
  type        = string
}

variable "availability_zone_2" {
  description = "Availability zone 2"
  type        = string
}

variable "route_cidr_block" {
  description = "CIDR block for the route"
  type        = string
}

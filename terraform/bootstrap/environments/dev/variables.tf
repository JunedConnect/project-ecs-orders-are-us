variable "aws_tags" {
  description = "Tags for Resources"
  type        = map(string)
}

variable "cloudflare_domain_name" {
  description = "The Cloudflare parent domain name"
  type        = string
}

variable "route53_domain_name" {
  description = "The Route53 delegated subdomain name"
  type        = string
}

variable "ecr_services" {
  description = "Set of service names that should each get an ECR repository"
  type        = set(string)
}

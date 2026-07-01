variable "cloudflare_domain_name" {
  description = "The Cloudflare parent domain name"
  type        = string
}

variable "route53_domain_name" {
  description = "The Route53 delegated subdomain name"
  type        = string
}

# variable "route53_name_servers" {
#   description = "Route53 name servers to publish in Cloudflare"
#   type        = list(string)
# }

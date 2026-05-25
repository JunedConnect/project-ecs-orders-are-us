# provider block here is required otherwise initialisation will not work as Terraform will default to hashicorp/cloudflare rather than cloudflare/cloudflare
terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
    }
  }
}

data "cloudflare_zone" "domain" {
  filter = {
    name = var.cloudflare_domain_name
  }
}

resource "cloudflare_dns_record" "domain" {
  for_each = toset(aws_route53_zone.this.name_servers)

  zone_id = data.cloudflare_zone.domain.id
  name    = var.route53_domain_name
  ttl     = 1
  type    = "NS"
  content = each.value
}

resource "aws_route53_zone" "this" {
  name = var.route53_domain_name
}

module "ecr" {
  source = "../../modules/ecr"

  environment  = var.aws_tags["Environment"]
  ecr_services = var.ecr_services
}

module "s3" {
  source = "../../modules/s3"

  environment = var.aws_tags["Environment"]
  project     = var.aws_tags["Project"]
}

module "domain" {
  source = "../../modules/domain"

  cloudflare_domain_name = var.cloudflare_domain_name
  route53_domain_name    = var.route53_domain_name
}

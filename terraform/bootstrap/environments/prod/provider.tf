terraform {
  required_version = ">= 1.12.2"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.95.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.15.0"
    }
  }
}

provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = var.aws_tags
  }
}
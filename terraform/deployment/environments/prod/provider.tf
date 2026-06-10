terraform {

  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.95.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
  backend "s3" {
    bucket       = "prod-orders-are-us-tfstate"
    key          = "terraform.tfstate"
    region       = "eu-west-2"
    encrypt      = "true"
    use_lockfile = true
  }

}


provider "aws" {
  region = "eu-west-2"
  default_tags {
    tags = var.aws-tags
  }
}

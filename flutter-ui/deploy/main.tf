terraform {
  backend "s3" {
    bucket         = "ahorro-app-state"
    key            = "dev/webapp/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "ahorro-app-state-lock"
    encrypt        = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.0"
}

provider "aws" {
  region = "eu-west-1"

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "ahorro-app"
      Service     = "ahorro-webapp-dev"
      Terraform   = "true"
    }
  }
}

data "aws_secretsmanager_secret" "domain" {
  name = "ahorro-app-secrets"
}

data "aws_secretsmanager_secret_version" "domain" {
  secret_id = data.aws_secretsmanager_secret.domain.id
}

locals {
  domain_name = jsondecode(data.aws_secretsmanager_secret_version.domain.secret_string)["domain_name"]
  subdomain   = "ahorro-dev"
  bucket_name = "${local.subdomain}-webapp"
}

data "aws_acm_certificate" "cert" {
  domain      = "*.${local.domain_name}"
  statuses    = ["ISSUED"]
  most_recent = true
}

data "aws_route53_zone" "main" {
  name = local.domain_name
}

module "webapp" {
  source              = "../../ahorro-shared/terraform/webapp"
  bucket_name         = local.bucket_name
  subdomain           = local.subdomain
  domain_name         = local.domain_name
  acm_certificate_arn = data.aws_acm_certificate.cert.arn
  zone_id             = data.aws_route53_zone.main.zone_id
}

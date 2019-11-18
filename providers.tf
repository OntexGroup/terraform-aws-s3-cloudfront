provider "aws" {
  region = "${var.aws["region"]}"
}

terraform {
  backend "s3" {
  }
}

data "aws_region" "current" {}

data "aws_availability_zones" "available" {}

data "aws_caller_identity" "current" {}

data "aws_route53_zone" "main" {
  count = length(var.dns["hostnames"]) > 0 ? 1 : 0
  name  = var.dns["domain_name"]
}

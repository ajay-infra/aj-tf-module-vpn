terraform {
  required_version = "= 1.7.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.100.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "= 4.0.5"
    }
  }

  # Backend configured dynamically by pipelines via -backend-config
  # backend "s3" {
  #   bucket         = "<tf-state-bucket>"
  #   key            = "network/vpn/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "tf-locks-central"
  #   role_arn       = "arn:aws:iam::ACCOUNT_ID:role/GitHubActions-Terraform"
  # }
}

provider "aws" {
  region = var.aws_region

  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  skip_region_validation      = true

  default_tags {
    tags = local.full_tags
  }
}

provider "tls" {}

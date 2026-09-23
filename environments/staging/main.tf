terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.98"
    }
  }

  backend "s3" {
    bucket         = "ebotprog-terraform-state"
    key            = "week6/staging/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.region
}

module "infra" {
  source = "../../modules/month1-infra"

  environment        = "staging"
  region             = var.region
  vpc_cidr           = var.vpc_cidr
  instance_type      = var.instance_type
  bastion_allowed_ip = var.bastion_allowed_ip
  key_name           = var.key_name
  bucket_name        = var.bucket_name

  mongo_root_password = var.mongo_root_password
  parse_master_key    = var.parse_master_key
  parse_app_id        = var.parse_app_id
  dashboard_user      = var.dashboard_user
  dashboard_password  = var.dashboard_password
}

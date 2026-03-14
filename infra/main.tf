terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "migrateiq-terraform-state-853973692277"
    key            = "migrateiq/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "migrateiq-terraform-lock"
    encrypt        = true
    profile        = "presidio-devops"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  default_tags {
    tags = {
      Project     = "MigrateIQ"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

module "networking" {
  source = "./modules/networking"

  project_name   = var.project_name
  environment    = var.environment
  vpc_cidr       = var.vpc_cidr
  allowed_ip     = var.allowed_ip
}

module "databases" {
  source = "./modules/databases"

  project_name        = var.project_name
  environment         = var.environment
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  public_subnet_ids   = module.networking.public_subnet_ids
  db_security_group_id = module.networking.db_security_group_id

  mysql_db_name       = var.mysql_db_name
  mysql_username      = var.mysql_username
  mysql_password      = var.mysql_password

  aurora_db_name      = var.aurora_db_name
  aurora_username     = var.aurora_username
  aurora_password     = var.aurora_password

  publicly_accessible = var.publicly_accessible
}

module "storage" {
  source = "./modules/storage"

  project_name = var.project_name
  environment  = var.environment
  aws_account_id = data.aws_caller_identity.current.account_id
}

data "aws_caller_identity" "current" {}

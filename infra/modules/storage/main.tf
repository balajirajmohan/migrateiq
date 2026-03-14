locals {
  name_prefix = "${var.project_name}-${var.environment}"
  bucket_name = "${var.project_name}-reports-${var.aws_account_id}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Module      = "storage"
  }
}

data "aws_caller_identity" "current" {}

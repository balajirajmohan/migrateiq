locals {
  name_prefix = "${var.project_name}-${var.environment}"
  subnet_ids  = var.publicly_accessible ? var.public_subnet_ids : var.private_subnet_ids

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    Module      = "databases"
  }
}

resource "aws_db_subnet_group" "this" {
  name        = "${local.name_prefix}-db-subnet"
  description = "Subnet group for MigrateIQ databases"
  subnet_ids  = local.subnet_ids

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-subnet"
  })
}

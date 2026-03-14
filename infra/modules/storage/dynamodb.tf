resource "aws_dynamodb_table" "migration_state" {
  name         = "${var.project_name}-migration-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "migration_id"

  attribute {
    name = "migration_id"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-migration-state"
  })
}

resource "aws_dynamodb_table" "knowledge_base" {
  name         = "${var.project_name}-knowledge-base"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "migration_id"
  range_key    = "timestamp"

  attribute {
    name = "migration_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-knowledge-base"
  })
}

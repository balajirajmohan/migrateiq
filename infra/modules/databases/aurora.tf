resource "aws_rds_cluster_parameter_group" "aurora" {
  name_prefix = "${local.name_prefix}-aurora-"
  family      = "aurora-postgresql15"
  description = "Cluster parameter group for MigrateIQ Aurora PostgreSQL target"

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-aurora-cluster-params"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_rds_cluster" "aurora_target" {
  cluster_identifier = "${local.name_prefix}-aurora-target"

  engine         = "aurora-postgresql"
  engine_version = "15.4"
  engine_mode    = "provisioned"

  database_name   = var.aurora_db_name
  master_username = var.aurora_username
  master_password = var.aurora_password

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.aurora.name
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [var.db_security_group_id]

  storage_encrypted = true

  serverlessv2_scaling_configuration {
    min_capacity = var.aurora_min_capacity
    max_capacity = var.aurora_max_capacity
  }

  backup_retention_period = var.backup_retention_period
  preferred_backup_window = "03:00-04:00"
  preferred_maintenance_window = "sun:04:30-sun:05:30"

  copy_tags_to_snapshot = true
  skip_final_snapshot   = var.environment == "dev" ? true : false
  deletion_protection   = var.deletion_protection

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-aurora-target"
    Role = "target"
  })

  depends_on = [aws_db_subnet_group.this]
}

resource "aws_rds_cluster_instance" "aurora_target" {
  identifier         = "${local.name_prefix}-aurora-target-1"
  cluster_identifier = aws_rds_cluster.aurora_target.id

  instance_class = "db.serverless"
  engine         = aws_rds_cluster.aurora_target.engine
  engine_version = aws_rds_cluster.aurora_target.engine_version

  publicly_accessible = var.publicly_accessible

  copy_tags_to_snapshot   = true
  auto_minor_version_upgrade = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-aurora-target-1"
    Role = "target"
  })
}

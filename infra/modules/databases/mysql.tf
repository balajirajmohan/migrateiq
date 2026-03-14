resource "aws_db_parameter_group" "mysql" {
  name_prefix = "${local.name_prefix}-mysql-"
  family      = "mysql8.0"
  description = "Parameter group for MigrateIQ MySQL source"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  parameter {
    name         = "log_bin_trust_function_creators"
    value        = "1"
    apply_method = "pending-reboot"
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-mysql-params"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "mysql_source" {
  identifier = "${local.name_prefix}-mysql-source"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.mysql_instance_class

  allocated_storage     = var.mysql_allocated_storage
  max_allocated_storage = var.mysql_allocated_storage * 2
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = var.mysql_db_name
  username = var.mysql_username
  password = var.mysql_password

  parameter_group_name   = aws_db_parameter_group.mysql.name
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [var.db_security_group_id]
  publicly_accessible    = var.publicly_accessible

  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:30-sun:05:30"

  auto_minor_version_upgrade = true
  copy_tags_to_snapshot      = true
  skip_final_snapshot        = var.environment == "dev" ? true : false
  deletion_protection        = var.deletion_protection

  enabled_cloudwatch_logs_exports = ["error", "slowquery"]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-mysql-source"
    Role = "source"
  })

  depends_on = [aws_db_subnet_group.this]
}

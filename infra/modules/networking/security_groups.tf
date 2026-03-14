# --- Database Security Group ---

resource "aws_security_group" "database" {
  name_prefix = "${local.name_prefix}-db-"
  description = "Controls access to MigrateIQ source and target databases"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "db_ingress_mysql_allowed_ip" {
  description       = "MySQL access from developer IP"
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_ip]
  security_group_id = aws_security_group.database.id
}

resource "aws_security_group_rule" "db_ingress_postgres_allowed_ip" {
  description       = "PostgreSQL access from developer IP"
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [var.allowed_ip]
  security_group_id = aws_security_group.database.id
}

resource "aws_security_group_rule" "db_ingress_mysql_vpc" {
  description       = "MySQL access from within VPC"
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.database.id
}

resource "aws_security_group_rule" "db_ingress_postgres_vpc" {
  description       = "PostgreSQL access from within VPC"
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.database.id
}

resource "aws_security_group_rule" "db_egress_all" {
  description       = "Allow all outbound traffic"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.database.id
}

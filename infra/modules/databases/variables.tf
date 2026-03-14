variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where databases will be deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for database deployment"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs (used only when publicly_accessible is true)"
  type        = list(string)
}

variable "db_security_group_id" {
  description = "Security group ID to attach to database instances"
  type        = string
}

# --- MySQL Source ---

variable "mysql_db_name" {
  description = "Database name for the MySQL source instance"
  type        = string
  default     = "migrateiq_source"

  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]*$", var.mysql_db_name))
    error_message = "mysql_db_name must start with a letter or underscore and contain only alphanumerics and underscores."
  }
}

variable "mysql_username" {
  description = "Master username for MySQL source"
  type        = string
  default     = "migrateiq_admin"
}

variable "mysql_password" {
  description = "Master password for MySQL source"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.mysql_password) >= 12
    error_message = "mysql_password must be at least 12 characters."
  }
}

variable "mysql_instance_class" {
  description = "Instance class for MySQL source"
  type        = string
  default     = "db.t3.micro"
}

variable "mysql_allocated_storage" {
  description = "Allocated storage in GB for MySQL source"
  type        = number
  default     = 20
}

# --- Aurora PostgreSQL Target ---

variable "aurora_db_name" {
  description = "Database name for the Aurora PostgreSQL target"
  type        = string
  default     = "migrateiq_target"
}

variable "aurora_username" {
  description = "Master username for Aurora PostgreSQL target"
  type        = string
  default     = "migrateiq_admin"
}

variable "aurora_password" {
  description = "Master password for Aurora PostgreSQL target"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.aurora_password) >= 12
    error_message = "aurora_password must be at least 12 characters."
  }
}

variable "aurora_min_capacity" {
  description = "Minimum ACU for Aurora Serverless v2"
  type        = number
  default     = 0.5
}

variable "aurora_max_capacity" {
  description = "Maximum ACU for Aurora Serverless v2"
  type        = number
  default     = 2.0
}

variable "publicly_accessible" {
  description = "Whether RDS instances are publicly accessible. True ONLY for local dev. Must be false in production."
  type        = bool
  default     = false
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups"
  type        = number
  default     = 7
}

variable "deletion_protection" {
  description = "Whether deletion protection is enabled. Should be true in production."
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "presidio-devops"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "migrateiq"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "allowed_ip" {
  description = "Your public IP address for database access (CIDR notation, e.g. 203.0.113.5/32). Set to your IP for dev, remove for production."
  type        = string
  sensitive   = true
}

# --- MySQL Source ---

variable "mysql_db_name" {
  description = "Database name for the MySQL source instance"
  type        = string
  default     = "migrateiq_source"
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
}

variable "publicly_accessible" {
  description = "Whether RDS instances are publicly accessible. True for local dev only. Must be false in production."
  type        = bool
  default     = false
}

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID used in globally unique resource names"
  type        = string
}

variable "enable_point_in_time_recovery" {
  description = "Enable point-in-time recovery for DynamoDB knowledge base table"
  type        = bool
  default     = true
}

variable "sns_email_endpoint" {
  description = "Email address to subscribe to migration alerts (optional, empty string to skip)"
  type        = string
  default     = ""
}

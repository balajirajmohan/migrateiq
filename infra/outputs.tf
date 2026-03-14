output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "mysql_endpoint" {
  description = "MySQL source database endpoint"
  value       = module.databases.mysql_endpoint
}

output "aurora_endpoint" {
  description = "Aurora PostgreSQL target database endpoint"
  value       = module.databases.aurora_endpoint
}

output "s3_bucket_name" {
  description = "S3 bucket for migration reports"
  value       = module.storage.s3_bucket_name
}

output "dynamodb_state_table" {
  description = "DynamoDB table for migration state"
  value       = module.storage.dynamodb_state_table
}

output "dynamodb_kb_table" {
  description = "DynamoDB table for knowledge base"
  value       = module.storage.dynamodb_kb_table
}

output "sns_topic_arn" {
  description = "SNS topic ARN for migration alerts"
  value       = module.storage.sns_topic_arn
}

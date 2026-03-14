output "s3_bucket_name" {
  description = "Name of the S3 bucket for migration reports"
  value       = aws_s3_bucket.reports.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for migration reports"
  value       = aws_s3_bucket.reports.arn
}

output "dynamodb_state_table" {
  description = "Name of the DynamoDB migration state table"
  value       = aws_dynamodb_table.migration_state.name
}

output "dynamodb_state_table_arn" {
  description = "ARN of the DynamoDB migration state table"
  value       = aws_dynamodb_table.migration_state.arn
}

output "dynamodb_kb_table" {
  description = "Name of the DynamoDB knowledge base table"
  value       = aws_dynamodb_table.knowledge_base.name
}

output "dynamodb_kb_table_arn" {
  description = "ARN of the DynamoDB knowledge base table"
  value       = aws_dynamodb_table.knowledge_base.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for migration alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_topic_name" {
  description = "Name of the SNS topic for migration alerts"
  value       = aws_sns_topic.alerts.name
}

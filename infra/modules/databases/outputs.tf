output "mysql_endpoint" {
  description = "MySQL source endpoint (host:port)"
  value       = aws_db_instance.mysql_source.endpoint
}

output "mysql_address" {
  description = "MySQL source hostname"
  value       = aws_db_instance.mysql_source.address
}

output "mysql_port" {
  description = "MySQL source port"
  value       = aws_db_instance.mysql_source.port
}

output "aurora_endpoint" {
  description = "Aurora PostgreSQL target writer endpoint"
  value       = aws_rds_cluster.aurora_target.endpoint
}

output "aurora_reader_endpoint" {
  description = "Aurora PostgreSQL target reader endpoint"
  value       = aws_rds_cluster.aurora_target.reader_endpoint
}

output "aurora_port" {
  description = "Aurora PostgreSQL target port"
  value       = aws_rds_cluster.aurora_target.port
}

output "mysql_identifier" {
  description = "MySQL source instance identifier"
  value       = aws_db_instance.mysql_source.identifier
}

output "aurora_cluster_identifier" {
  description = "Aurora target cluster identifier"
  value       = aws_rds_cluster.aurora_target.cluster_identifier
}

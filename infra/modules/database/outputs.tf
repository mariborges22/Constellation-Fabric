output "db_instance_endpoint" {
  value = aws_db_instance.game_db.endpoint
}

output "db_instance_address" {
  value = aws_db_instance.game_db.address
}

output "db_secret_arn" {
  value       = aws_secretsmanager_secret.db_url.arn
  description = "ARN do Secrets Manager com a DATABASE_URL"
}

output "rds_kms_arn" {
  value       = aws_kms_key.rds.arn
  description = "ARN da chave KMS usada no RDS e Secrets"
}

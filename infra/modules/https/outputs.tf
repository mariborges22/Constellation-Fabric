output "tunnel_secret_arn" {
  value       = aws_secretsmanager_secret.cloudflare_tunnel_token.arn
  description = "ARN do Secret que armazena o Cloudflare Tunnel Token"
  sensitive   = true
}

output "access_logs_bucket" {
  value       = aws_s3_bucket.cf_logs.id
  description = "S3 bucket for access logs"
  sensitive   = true
}

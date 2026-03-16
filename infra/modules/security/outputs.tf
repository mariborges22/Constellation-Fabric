output "github_actions_role_arn" {
  value       = var.create_global_resources ? aws_iam_role.github_actions_role[0].arn : ""
  description = "ARN da Role IAM para o GitHub Actions"
}

output "oidc_provider_arn" {
  value       = var.create_global_resources ? aws_iam_openid_connect_provider.github[0].arn : ""
  description = "ARN do provider OIDC"
}

output "jwt_secret_arn" {
  value       = aws_secretsmanager_secret.jwt_keys.arn
  description = "ARN do secret com as chaves JWT"
}
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions_role.arn
  description = "ARN da Role para configurar no seu GitHub Environment"
  sensitive   = true
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}
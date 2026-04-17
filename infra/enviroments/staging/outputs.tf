output "oidc_role_arn" {
  value       = module.security.github_actions_role_arn
  description = "ARN da Role OIDC para o GitHub Actions"
  sensitive   = true
}

output "oidc_provider_arn" {
  value       = module.security.oidc_provider_arn
  description = "ARN do OIDC Provider"
}

output "vpc_us_east_id" {
  value = module.networks_us.vpc_id
}

output "vpc_eu_west_id" {
  value = module.networks_eu.vpc_id
}

output "alb_dns_us" {
  value       = module.networks_us.alb_dns_name
  description = "ALB DNS name (us-east-1)"
}

output "alb_dns_eu" {
  value       = module.networks_eu.alb_dns_name
  description = "ALB DNS name (eu-west-1)"
}

output "alb_url_us" {
  value       = "http://${module.networks_us.alb_dns_name}"
}

output "alb_url_eu" {
  value       = "http://${module.networks_eu.alb_dns_name}"
}

# DynamoDB Table Names (Replicas)
output "player_state_table_name" {
  value = module.database_global.player_state_table_arn
}

output "combat_logs_table_name" {
  value = module.database_global.combat_logs_table_arn
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

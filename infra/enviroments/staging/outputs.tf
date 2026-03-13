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

# ALB DNS Names (pra usar no CloudFlare)
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
  description = "ALB URL (us-east-1)"
}

output "alb_url_eu" {
  value       = "http://${module.networks_eu.alb_dns_name}"
  description = "ALB URL (eu-west-1)"
}

output "cloudflare_instructions" {
  value = "Add these to CloudFlare DNS:\n- game.constellation.com → ${module.networks_us.alb_dns_name}\n- api.constellation.com → ${module.networks_us.alb_dns_name}\n- auth.constellation.com → ${module.networks_us.alb_dns_name}\n- game-eu.constellation.com → ${module.networks_eu.alb_dns_name}"
}

output "grafana_url" {
  value = module.monitoring.grafana_url
}

output "tempo_endpoint" {
  value = module.monitoring.tempo_endpoint
}

output "prometheus_url" {
  value = module.monitoring.prometheus_url
}

# ECR repositórios
output "ecr_auth_uri" {
  value = module.compute_us.repository_url_auth
}

output "ecr_combat_uri" {
  value = module.compute_us.repository_url_combat
}

output "ecr_event_publisher_uri" {
  value = module.compute_us.repository_url_event_publisher
}

# HTTPS / Cloudflare Tunnel
output "tunnel_secret_arn" {
  value       = module.https.tunnel_secret_arn
  description = "ARN do Secret com o token do Cloudflare Tunnel"
  sensitive   = true
}

output "cf_access_logs_bucket" {
  value     = module.https.access_logs_bucket
  sensitive = true
}


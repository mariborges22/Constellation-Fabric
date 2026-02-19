output "oidc_role_arn" {
  value       = module.security.github_actions_role_arn
  description = "ARN da Role OIDC para o GitHub Actions"
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

output "alb_us_dns" {
  value = module.networks_us.alb_dns_name
}

output "alb_eu_dns" {
  value = module.networks_eu.alb_dns_name
}

output "accelerator_ips" {
  value = concat(module.networks_us.accelerator_ips, module.networks_eu.accelerator_ips)
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

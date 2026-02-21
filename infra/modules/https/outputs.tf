output "https_game_url" {
  value       = "https://game.${var.domain_name}"
  description = "HTTPS URL para game"
}

output "https_api_url" {
  value       = "https://api.${var.domain_name}"
  description = "HTTPS URL para API"
}

output "https_auth_url" {
  value       = "https://auth.${var.domain_name}"
  description = "HTTPS URL para Auth"
}

output "route53_zone_id" {
  value       = var.route53_zone_id
  description = "Route 53 Zone ID"
}

output "us_alb_dns" {
  value = module.networks_us.alb_dns_name
}

output "eu_alb_dns" {
  value = module.networks_eu.alb_dns_name
}

output "project_name" {
  value = var.project_name
}

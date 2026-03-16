output "us_alb_dns" {
  value = module.networks_us.alb_dns_name
}

output "eu_alb_dns" {
  value = module.networks_eu.alb_dns_name
}

output "kinesis_stream_us_name" {
  value = module.data_us.kinesis_stream_name
}

output "kinesis_stream_eu_name" {
  value = module.data_eu.kinesis_stream_name
}

output "project_name" {
  value = var.project_name
}

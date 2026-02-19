output "grafana_url" {
  value = "https://grafana.${var.project_name}.io"
}

output "tempo_endpoint" {
  value = "tempo.${var.project_name}.io:4317"
}

output "prometheus_url" {
  value = "https://prometheus.${var.project_name}.io"
}

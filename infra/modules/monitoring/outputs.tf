output "grafana_access_info" {
  value = "Grafana is available on port 3000 of its ECS Task Public IP. Run 'scripts/get-monitoring-ips.ps1' to find it."
}

output "prometheus_access_info" {
  value = "Prometheus is available on port 9090 of its ECS Task Public IP. Run 'scripts/get-monitoring-ips.ps1' to find it."
}

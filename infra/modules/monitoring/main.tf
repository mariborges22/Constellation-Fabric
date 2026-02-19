# Placeholder para Grafana
resource "null_resource" "grafana_mock" {
  triggers = {
    project = var.project_name
  }
}

# Placeholder para Prometheus
resource "null_resource" "prometheus_mock" {
  triggers = {
    project = var.project_name
  }
}

# Placeholder para Tempo
resource "null_resource" "tempo_mock" {
  triggers = {
    project = var.project_name
  }
}

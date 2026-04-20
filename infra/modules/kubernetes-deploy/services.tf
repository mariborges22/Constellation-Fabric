# Auth Service Configuration
resource "kubernetes_manifest" "auth_service_account" {
  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "auth-service"
      namespace = "constellation"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.auth_irsa_role_arn
      }
    }
  }
}

resource "kubernetes_manifest" "auth_deployment" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "auth-service"
      namespace = "constellation"
    }
    spec = {
      replicas = 2
      selector = {
        matchLabels = {
          app = "auth"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "auth"
          }
        }
        spec = {
          serviceAccountName = "auth-service"
          containers = [{
            name  = "auth"
            image = var.auth_image
            ports = [{ containerPort = 8080 }]
            env = [
              { name = "DYNAMO_TABLE_NAME", value = var.player_state_table_name },
              { name = "AWS_REGION", value = var.region }
            ]
            resources = {
              limits   = { cpu = "500m", memory = "512Mi" }
              requests = { cpu = "100m", memory = "128Mi" }
            }
            readinessProbe = {
              httpGet = { path = "/health", port = 8080 }
              initialDelaySeconds = 5
              periodSeconds        = 10
            }
          }]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "auth_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "auth-service"
      namespace = "constellation"
    }
    spec = {
      selector = { app = "auth" }
      ports = [{ port = 80, targetPort = 8080 }]
      type = "ClusterIP"
    }
  }
}

# Combat Service Configuration
resource "kubernetes_manifest" "combat_service_account" {
  manifest = {
    apiVersion = "v1"
    kind       = "ServiceAccount"
    metadata = {
      name      = "combat-service"
      namespace = "constellation"
      annotations = {
        "eks.amazonaws.com/role-arn" = var.combat_irsa_role_arn
      }
    }
  }
}

resource "kubernetes_manifest" "combat_deployment" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "combat-service"
      namespace = "constellation"
    }
    spec = {
      replicas = 2
      selector = {
        matchLabels = {
          app = "combat"
        }
      }
      template = {
        metadata = {
          labels = {
            app = "combat"
          }
        }
        spec = {
          serviceAccountName = "combat-service"
          containers = [{
            name  = "combat"
            image = var.combat_image
            ports = [{ containerPort = 8080 }]
            env = [
              { name = "DYNAMO_TABLE_NAME", value = var.combat_logs_table_name },
              { name = "AWS_REGION", value = var.region }
            ]
            resources = {
              limits   = { cpu = "500m", memory = "512Mi" }
              requests = { cpu = "100m", memory = "128Mi" }
            }
            readinessProbe = {
              httpGet = { path = "/health", port = 8080 }
              initialDelaySeconds = 5
              periodSeconds        = 10
            }
          }]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "combat_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "combat-service"
      namespace = "constellation"
    }
    spec = {
      selector = { app = "combat" }
      ports = [{ port = 80, targetPort = 8080 }]
      type = "ClusterIP"
    }
  }
}

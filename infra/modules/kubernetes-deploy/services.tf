# Auth Service Configuration
resource "kubernetes_service_account" "auth" {
  metadata {
    name      = "auth-service"
    namespace = "constellation"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.auth_irsa_role_arn
    }
  }
}

resource "kubernetes_deployment" "auth" {
  metadata {
    name      = "auth-service"
    namespace = "constellation"
  }

  wait_for_rollout = false

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "auth"
      }
    }

    template {
      metadata {
        labels = {
          app = "auth"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.auth.metadata[0].name  
        container {
          name  = "auth"
          image = var.auth_image

          port {
            container_port = 8080
          }

          env {
            name  = "DYNAMO_TABLE_NAME"
            value = var.player_state_table_name
          }

          env {
            name  = "AWS_REGION"
            value = var.region
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "auth" {
  metadata {
    name      = "auth-service"
    namespace = "constellation"
  }

  spec {
    selector = {
      app = "auth"
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

# Combat Service Configuration
resource "kubernetes_service_account" "combat" {
  metadata {
    name      = "combat-service"
    namespace = "constellation"
    annotations = {
      "eks.amazonaws.com/role-arn" = var.combat_irsa_role_arn
    }
  }
}

resource "kubernetes_deployment" "combat" {
  metadata {
    name      = "combat-service"
    namespace = "constellation"
  }

  wait_for_rollout = false

  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "combat"
      }
    }

    template {
      metadata {
        labels = {
          app = "combat"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.combat.metadata[0].name
        container {
          name  = "combat"
          image = var.combat_image

          port {
            container_port = 8080
          }

          env {
            name  = "DYNAMO_TABLE_NAME"
            value = var.combat_logs_table_name
          }

          env {
            name  = "AWS_REGION"
            value = var.region
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "combat" {
  metadata {
    name      = "combat-service"
    namespace = "constellation"
  }

  spec {
    selector = {
      app = "combat"
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "ClusterIP"
  }
}

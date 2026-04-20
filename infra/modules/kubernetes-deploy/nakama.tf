resource "kubernetes_storage_class" "gp3" {
  metadata {
    name = "gp3"
  }
  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Retain"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type = "gp3"
  }
}

# Nakama ConfigMap
resource "kubernetes_config_map" "nakama_config" {
  metadata {
    name      = "nakama-config"
    namespace = "constellation"
  }

  data = {
    "local.yml" = <<EOF
name: nakama-server
database:
  address: "postgres:nakama_password_change_me@nakama-db:5432/nakama"
logger:
  level: "info"
  format: "json"
session:
  encryption_key: "default-encryption-key-change-me"
socket:
  port: 7350
console:
  port: 7349
  username: "admin"
  password: "password"
EOF
  }
}

# Nakama Database (PostgreSQL)
resource "kubernetes_service" "nakama_db" {
  metadata {
    name      = "nakama-db"
    namespace = "constellation"
  }

  spec {
    selector = {
      app = "nakama-db"
    }
    port {
      port = 5432
    }
    cluster_ip = "None"
  }
}

resource "kubernetes_stateful_set" "nakama_db" {
  metadata {
    name      = "nakama-db"
    namespace = "constellation"
  }

  spec {
    service_name = "nakama-db"
    replicas     = 1

    selector {
      match_labels = {
        app = "nakama-db"
      }
    }

    template {
      metadata {
        labels = {
          app = "nakama-db"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:14-alpine"

          env {
            name  = "POSTGRES_DB"
            value = "nakama"
          }
          env {
            name  = "POSTGRES_PASSWORD"
            value = "nakama_password_change_me"
          }
          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          port {
            container_port = 5432
            name           = "postgres"
          }

          volume_mount {
            name       = "nakama-db-storage"
            mount_path = "/var/lib/postgresql/data"
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "nakama-db-storage"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "gp3"
        resources {
          requests = {
            storage = "10Gi"
          }
        }
      }
    }
  }
}

# Nakama Server
resource "kubernetes_deployment" "nakama" {
  metadata {
    name      = "nakama"
    namespace = "constellation"
  }

  wait_for_rollout = false

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "nakama"
      }
    }

    template {
      metadata {
        labels = {
          app = "nakama"
        }
      }

      spec {
        container {
          name  = "nakama"
          image = "heroiclabs/nakama:3.22.0"

          command = ["/bin/sh", "-ecx", "/nakama/nakama migrate up --database.address postgres:nakama_password_change_me@nakama-db:5432/nakama && /nakama/nakama --config /nakama/data/local.yml --database.address postgres:nakama_password_change_me@nakama-db:5432/nakama"]

          port {
            container_port = 7349
            name           = "console"
          }
          port {
            container_port = 7350
            name           = "api"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_stateful_set.nakama_db]
}

resource "kubernetes_service" "nakama" {
  metadata {
    name      = "nakama"
    namespace = "constellation"
  }

  spec {
    selector = {
      app = "nakama"
    }
    port {
      port        = 7349
      target_port = 7349
      name        = "console"
    }
    port {
      port        = 7350
      target_port = 7350
      name        = "api"
    }
    type = "ClusterIP"
  }
}

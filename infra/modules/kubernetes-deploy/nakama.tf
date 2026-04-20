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
resource "kubernetes_manifest" "nakama_config" {
  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
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
}

# Nakama Database (PostgreSQL)
resource "kubernetes_manifest" "nakama_db_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "nakama-db"
      namespace = "constellation"
    }
    spec = {
      selector = { app = "nakama-db" }
      clusterIP = "None"
      ports = [{ port = 5432 }]
    }
  }
}

resource "kubernetes_manifest" "nakama_db_statefulset" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "StatefulSet"
    metadata = {
      name      = "nakama-db"
      namespace = "constellation"
    }
    spec = {
      serviceName = "nakama-db"
      replicas    = 1
      selector = {
        matchLabels = { app = "nakama-db" }
      }
      template = {
        metadata = {
          labels = { app = "nakama-db" }
        }
        spec = {
          containers = [{
            name  = "postgres"
            image = "postgres:14-alpine"
            env = [
              { name = "POSTGRES_DB", value = "nakama" },
              { name = "POSTGRES_PASSWORD", value = "nakama_password_change_me" },
              { name = "PGDATA", value = "/var/lib/postgresql/data/pgdata" }
            ]
            ports = [{ containerPort = 5432, name = "postgres" }]
            volumeMounts = [{ name = "nakama-db-storage", mountPath = "/var/lib/postgresql/data" }]
          }]
        }
      }
      volumeClaimTemplates = [{
        metadata = { name = "nakama-db-storage" }
        spec = {
          accessModes = ["ReadWriteOnce"]
          storageClassName = "gp3"
          resources = {
            requests = { storage = "10Gi" }
          }
        }
      }]
    }
  }
}

# Nakama Server
resource "kubernetes_manifest" "nakama_deployment" {
  manifest = {
    apiVersion = "apps/v1"
    kind       = "Deployment"
    metadata = {
      name      = "nakama"
      namespace = "constellation"
    }
    spec = {
      replicas = 1
      selector = {
        matchLabels = { app = "nakama" }
      }
      template = {
        metadata = {
          labels = { app = "nakama" }
        }
        spec = {
          containers = [{
            name  = "nakama"
            image = "heroiclabs/nakama:3.22.0"
            command = ["/bin/sh", "-ecx", "/nakama/nakama migrate up --database.address postgres:nakama_password_change_me@nakama-db:5432/nakama && /nakama/nakama --config /nakama/data/local.yml --database.address postgres:nakama_password_change_me@nakama-db:5432/nakama"]
            ports = [
              { containerPort = 7349, name = "console" },
              { containerPort = 7350, name = "api" }
            ]
            resources = {
              limits   = { cpu = "500m", memory = "512Mi" }
              requests = { cpu = "100m", memory = "256Mi" }
            }
          }]
        }
      }
    }
  }

  depends_on = [kubernetes_manifest.nakama_db_statefulset]
}

resource "kubernetes_manifest" "nakama_service" {
  manifest = {
    apiVersion = "v1"
    kind       = "Service"
    metadata = {
      name      = "nakama"
      namespace = "constellation"
    }
    spec = {
      selector = { app = "nakama" }
      ports = [
        { name = "console", port = 7349, targetPort = 7349 },
        { name = "api", port = 7350, targetPort = 7350 }
      ]
      type = "ClusterIP"
    }
  }
}

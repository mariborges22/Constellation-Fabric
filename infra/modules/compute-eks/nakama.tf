# PostgreSQL Database for Nakama
resource "helm_release" "nakama_postgres" {
  name       = "nakama-postgres"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = "constellation"

  set {
    name  = "auth.postgresPassword"
    value = "supersecretpassword123" # Em produção, usar AWS Secrets Manager
  }

  set {
    name  = "auth.username"
    value = "nakama"
  }

  set {
    name  = "auth.password"
    value = "nakama"
  }

  set {
    name  = "auth.database"
    value = "nakama"
  }

  set {
    name  = "primary.persistence.enabled"
    value = "true"
  }

  set {
    name  = "primary.persistence.size"
    value = "10Gi"
  }
}

# Heroic Labs Nakama Server
resource "helm_release" "nakama" {
  name       = "nakama"
  repository = "https://heroiclabs.github.io/helm-charts"
  chart      = "nakama"
  namespace  = "constellation"

  set {
    name  = "image.repository"
    value = "721529235452.dkr.ecr.us-east-1.amazonaws.com/constellation-fabric-staging-nakama"
  }

  set {
    name  = "image.tag"
    value = "latest"
  }

  set {
    name  = "nakama.db.address"
    value = "nakama:nakama@nakama-postgres.constellation.svc.cluster.local:5432/nakama"
  }

  set {
    name  = "nakama.console.password"
    value = "admin_password" # Console admin password
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  # Injeta as URLs dos serviços Rust para o módulo Lua
  set {
    name  = "nakama.environment.PLAYER_STATE_API"
    value = "http://player-state-service:80"
  }

  set {
    name  = "nakama.environment.COMBAT_API"
    value = "http://combat-service:80"
  }

  depends_on = [
    helm_release.nakama_postgres
  ]
}

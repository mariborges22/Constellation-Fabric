# Auth Service Configuration
resource "kubernetes_manifest" "auth_service_account" {
  field_manager {
    force_conflicts = true
  }
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

# Combat Service Configuration
resource "kubernetes_manifest" "combat_service_account" {
  field_manager {
    force_conflicts = true
  }
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

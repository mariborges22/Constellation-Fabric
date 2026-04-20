resource "kubernetes_ingress_v1" "main" {
  metadata {
    name      = "constellation-ingress"
    namespace = "constellation"
    annotations = {
      "kubernetes.io/ingress.class"               = "alb"
      "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"     = "ip"
      "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/healthcheck-path" = "/health"
      "alb.ingress.kubernetes.io/success-codes"   = "200"
    }
  }

  spec {
    rule {
      http {
        path {
          path      = "/api/v1/auth"
          path_type = "Prefix"
          backend {
            service {
              name = "auth-service"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/api/v1/combat"
          path_type = "Prefix"
          backend {
            service {
              name = "combat-service"
              port {
                number = 80
              }
            }
          }
        }

        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "nakama"
              port {
                number = 7350
              }
            }
          }
        }

        path {
          path      = "/console"
          path_type = "Prefix"
          backend {
            service {
              name = "nakama"
              port {
                number = 7349
              }
            }
          }
        }
      }
    }
  }
}

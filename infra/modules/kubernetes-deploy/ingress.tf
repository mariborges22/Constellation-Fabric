resource "kubernetes_manifest" "main_ingress" {
  manifest = {
    apiVersion = "networking.k8s.io/v1"
    kind       = "Ingress"
    metadata = {
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

    spec = {
      rules = [{
        http = {
          paths = [
            {
              path      = "/api/v1/auth"
              pathType  = "Prefix"
              backend = {
                service = {
                  name = "auth-service"
                  port = { number = 80 }
                }
              }
            },
            {
              path      = "/api/v1/combat"
              pathType  = "Prefix"
              backend = {
                service = {
                  name = "combat-service"
                  port = { number = 80 }
                }
              }
            },
            {
              path      = "/"
              pathType  = "Prefix"
              backend = {
                service = {
                  name = "nakama"
                  port = { number = 7350 }
                }
              }
            },
            {
              path      = "/console"
              pathType  = "Prefix"
              backend = {
                service = {
                  name = "nakama"
                  port = { number = 7349 }
                }
              }
            }
          ]
        }
      }]
    }
  }
}

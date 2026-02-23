# =============================================================
# Cloudflare Tunnel Infrastructure Module
# TLS Termination: Cloudflare Edge → cloudflared sidecar → ALB
# =============================================================

# --- S3 Bucket for Access Logs (retained from previous plan) ---
resource "aws_s3_bucket" "cf_logs" {
  bucket        = "${var.project_name}-${var.aws_region}-cf-logs" # Keep original name to prevent forced destroy
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "cf_logs" {
  bucket = aws_s3_bucket.cf_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "cf_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.cf_logs]
  bucket     = aws_s3_bucket.cf_logs.id
  acl        = "private"
}

# --- AWS Secrets Manager: Store the Cloudflare Tunnel Token ---
# You must populate this secret manually AFTER creating the Tunnel in the Cloudflare Dashboard.
# The tunnel token is sensitive and must never be stored in plain text in the repo.
resource "aws_secretsmanager_secret" "cloudflare_tunnel_token" {
  name                    = "${var.project_name}/cloudflare-tunnel-token"
  description             = "Cloudflare Tunnel token for constellation-fabric-tunnel"
  recovery_window_in_days = 7

  lifecycle {
    prevent_destroy = true
  }
}

# Placeholder value — populate manually via AWS Console or CLI before deploying ECS.
# Command: aws secretsmanager put-secret-value --secret-id "${ var.project_name}/cloudflare-tunnel-token" --secret-string "YOUR_TUNNEL_TOKEN"
resource "aws_secretsmanager_secret_version" "cloudflare_tunnel_token" {
  secret_id     = aws_secretsmanager_secret.cloudflare_tunnel_token.id
  secret_string = "REPLACE_ME_WITH_YOUR_CLOUDFLARED_TUNNEL_TOKEN"

  lifecycle {
    # Prevent Terraform from wiping the real token if you manage it manually
    ignore_changes = [secret_string]
  }
}

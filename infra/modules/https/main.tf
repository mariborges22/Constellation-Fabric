# S3 Bucket for CloudFront Logs
resource "aws_s3_bucket" "cf_logs" {
  bucket = "${var.project_name}-${var.aws_region}-cf-logs"
  force_destroy = false # Changed to false for better safety

  lifecycle {
    prevent_destroy = true
  }
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "game_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront for Constellation Fabric - ${var.project_name}"
  price_class         = "PriceClass_100" # Lowest cost (US, Canada, Europe)

  lifecycle {
    prevent_destroy = true
  }
  # Rest of the config...

  # Logging configuration for EDA
  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.cf_logs.bucket_domain_name
    prefix          = "cloudfront-logs/"
  }

  origin {
    domain_name = var.alb_dns_name
    origin_id   = "ALB-Origin"

    custom_origin_config {
      http_port                = 80
      https_port               = 443
      origin_protocol_policy    = "http-only" # Our ALB is currently HTTP only on port 80
      origin_ssl_protocols      = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB-Origin"

    forwarded_values {
      query_string = true
      headers      = ["*"] # Forward all headers (dynamic behavior)

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0 # No caching for dynamic game events
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true # Use *.cloudfront.net
  }

  tags = {
    Name = "${var.project_name}-cf"
  }
}

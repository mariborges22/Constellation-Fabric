output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.game_distribution.domain_name
  description = "Domain name of the CloudFront distribution"
}

output "https_url" {
  value       = "https://${aws_cloudfront_distribution.game_distribution.domain_name}"
  description = "Base HTTPS URL for the game via CloudFront"
}

output "cf_logs_bucket" {
  value       = aws_s3_bucket.cf_logs.bucket
  description = "S3 bucket for CloudFront logs"
}

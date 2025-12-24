# outputs.tf
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for main site"
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name for main site"
  value       = aws_cloudfront_distribution.site.domain_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for site content"
  value       = aws_s3_bucket.site.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN for site content"
  value       = aws_s3_bucket.site.arn
}

output "primary_domain" {
  description = "Primary domain for the site"
  value       = local.primary_domain
}

output "redirect_domain" {
  description = "Redirect domain"
  value       = local.redirect_domain
}

output "nameservers" {
  description = "Route 53 nameservers for domain configuration"
  value       = data.aws_route53_zone.site.name_servers
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN (for GitHub Actions)"
  value       = aws_cloudfront_distribution.site.arn
}
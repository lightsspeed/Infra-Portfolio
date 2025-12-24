# Variables
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "domain_name" {
  description = "Domain name for the portfolio site (e.g., example.com)"
  type        = string
}

variable "www_redirect" {
  description = "Redirect www to apex (true) or apex to www (false)"
  type        = bool
  default     = true # true = www -> apex, false = apex -> www
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (e.g., PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_100"
}

variable "log_retention_days" {
  description = "Number of days to retain CloudFront/S3 logs"
  type        = number
  default     = 30
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "error_4xx_threshold" {
  description = "Threshold for 4xx errors to trigger CloudWatch alarm (percentage)"
  type        = number
  default     = 5
}

variable "error_5xx_threshold" {
  description = "Threshold for 5xx errors to trigger CloudWatch alarm (percentage)"
  type        = number
  default     = 1
}

locals {
  primary_domain  = var.www_redirect ? var.domain_name : "www.${var.domain_name}"
  redirect_domain = var.www_redirect ? "www.${var.domain_name}" : var.domain_name
}

# Provider for us-east-1 (required for ACM certificates used by CloudFront)
provider "aws" {
  region = var.aws_region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

# S3 Bucket for main site content (private)
resource "aws_s3_bucket" "site" {
  bucket = local.primary_domain
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "site" {
  bucket = aws_s3_bucket.site.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket for CloudFront logs (private)
resource "aws_s3_bucket" "logs" {
  bucket = "${local.primary_domain}-logs"
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "logs" {
  bucket = aws_s3_bucket.logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "logs" {
  depends_on = [aws_s3_bucket_ownership_controls.logs]
  bucket     = aws_s3_bucket.logs.id
  acl        = "private"
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id     = "log-expiration"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }
  }
}

# S3 Bucket for redirect (private — no website hosting needed)
resource "aws_s3_bucket" "redirect" {
  bucket = local.redirect_domain
}

resource "aws_s3_bucket_public_access_block" "redirect" {
  bucket = aws_s3_bucket.redirect.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Control for main site
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${local.primary_domain}-oac"
  description                       = "OAC for ${local.primary_domain}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 Bucket Policy for main site — allows only CloudFront
resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.site.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.site.arn
          }
        }
      }
    ]
  })
}

# CloudFront Origin Access Control for redirect bucket
resource "aws_cloudfront_origin_access_control" "redirect" {
  name                              = "${local.redirect_domain}-oac"
  description                       = "OAC for redirect bucket ${local.redirect_domain}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 Bucket Policy for redirect — allows only CloudFront
resource "aws_s3_bucket_policy" "redirect" {
  bucket = aws_s3_bucket.redirect.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.redirect.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.redirect.arn
          }
        }
      }
    ]
  })
}

# ACM Certificate (must be in us-east-1 for CloudFront)
resource "aws_acm_certificate" "site" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = [
    "www.${var.domain_name}"
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Route 53 Hosted Zone
data "aws_route53_zone" "site" {
  name         = var.domain_name
  private_zone = false
}

# Route 53 records for ACM validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.site.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.site.zone_id
}

# ACM Certificate Validation
resource "aws_acm_certificate_validation" "site" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# CloudFront Function for security headers and clean URLs
resource "aws_cloudfront_function" "headers" {
  name    = "${replace(local.primary_domain, ".", "-")}-headers"
  runtime = "cloudfront-js-2.0"
  comment = "Add security headers and handle clean URLs"
  publish = true
  code    = <<-EOT
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    // Add .html extension if no file extension
    if (!uri.includes('.')) {
        request.uri = uri + '.html';
    }
    
    // Handle directory index
    if (uri.endsWith('/')) {
        request.uri = uri + 'index.html';
    }
    
    return request;
}
EOT
}

resource "aws_cloudfront_function" "security_headers" {
  name    = "${replace(local.primary_domain, ".", "-")}-security"
  runtime = "cloudfront-js-2.0"
  comment = "Add security headers to responses"
  publish = true
  code    = <<-EOT
function handler(event) {
    var response = event.response;
    var headers = response.headers;
    
    headers['strict-transport-security'] = { value: 'max-age=63072000; includeSubdomains; preload' };
    headers['x-content-type-options'] = { value: 'nosniff' };
    headers['x-frame-options'] = { value: 'DENY' };
    headers['x-xss-protection'] = { value: '1; mode=block' };
    headers['referrer-policy'] = { value: 'strict-origin-when-cross-origin' };
    
    return response;
}
EOT
}

# CloudFront Distribution - Main Site
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [local.primary_domain]
  price_class         = var.cloudfront_price_class

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "S3-${local.primary_domain}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${local.primary_domain}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.headers.arn
    }

    function_association {
      event_type   = "viewer-response"
      function_arn = aws_cloudfront_function.security_headers.arn
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  custom_error_response {
    error_code         = 404
    response_code      = 404
    response_page_path = "/404.html"
  }

  custom_error_response {
    error_code         = 403
    response_code      = 404
    response_page_path = "/404.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logs.bucket_domain_name
    prefix          = "cloudfront/"
  }

  depends_on = [aws_acm_certificate_validation.site]
}

# CloudFront Distribution - Redirect (www → apex or vice versa)
resource "aws_cloudfront_distribution" "redirect" {
  enabled         = true
  is_ipv6_enabled = true
  aliases         = [local.redirect_domain]
  price_class     = var.cloudfront_price_class

  origin {
    domain_name              = aws_s3_bucket.redirect.bucket_regional_domain_name
    origin_id                = "S3-${local.redirect_domain}"
    origin_access_control_id = aws_cloudfront_origin_access_control.redirect.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${local.redirect_domain}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.site.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  depends_on = [aws_acm_certificate_validation.site]
}

# Route 53 A Record - Primary domain
resource "aws_route53_record" "primary" {
  zone_id = data.aws_route53_zone.site.zone_id
  name    = local.primary_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# Route 53 A Record - Redirect domain
resource "aws_route53_record" "redirect" {
  zone_id = data.aws_route53_zone.site.zone_id
  name    = local.redirect_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.redirect.domain_name
    zone_id                = aws_cloudfront_distribution.redirect.hosted_zone_id
    evaluate_target_health = false
  }
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx_errors" {
  alarm_name          = "${local.primary_domain}-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = var.error_5xx_threshold
  alarm_description   = "This metric monitors CloudFront 5xx error rate"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
  }
}

resource "aws_cloudwatch_metric_alarm" "cloudfront_4xx_errors" {
  alarm_name          = "${local.primary_domain}-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "4xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 300
  statistic           = "Average"
  threshold           = var.error_4xx_threshold
  alarm_description   = "This metric monitors CloudFront 4xx error rate"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
  }
}

# Outputs
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
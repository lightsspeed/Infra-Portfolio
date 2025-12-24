# variables.tf
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
  default     = true
}

variable "log_retention_days" {
  description = "Number of days to retain CloudFront logs"
  type        = number
  default     = 90
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_100, PriceClass_200, PriceClass_All)"
  type        = string
  default     = "PriceClass_100"
}

variable "error_4xx_threshold" {
  description = "Threshold for 4xx error rate alarm (percentage)"
  type        = number
  default     = 10
}

variable "error_5xx_threshold" {
  description = "Threshold for 5xx error rate alarm (percentage)"
  type        = number
  default     = 5
}
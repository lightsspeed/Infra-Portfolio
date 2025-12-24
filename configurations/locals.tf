# locals.tf
locals {
  primary_domain  = var.www_redirect ? var.domain_name : "www.${var.domain_name}"
  redirect_domain = var.www_redirect ? "www.${var.domain_name}" : var.domain_name
  
  common_tags = {
    Project     = "Portfolio"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }
}
data "aws_route53_zone" "site" {
  name         = var.domain_name
  private_zone = false
}
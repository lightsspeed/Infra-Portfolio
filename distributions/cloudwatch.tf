# cloudwatch.tf
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
  tags                = merge(local.common_tags, { Name = "5xx Error Alarm" })

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
  tags                = merge(local.common_tags, { Name = "4xx Error Alarm" })

  dimensions = {
    DistributionId = aws_cloudfront_distribution.site.id
  }
}
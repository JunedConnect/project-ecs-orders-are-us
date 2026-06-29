output "waf_log_group_arn" {
  description = "ARN of the CloudWatch log group used for WAF logging"
  value       = aws_cloudwatch_log_group.waf.arn
}

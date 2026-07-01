output "alb_dns_name" {
  value = aws_lb.this.dns_name
}

output "alb_zone_id" {
  value = aws_lb.this.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.api_gateway.arn
}

output "dashboard_target_group_arn" {
  value = aws_lb_target_group.dashboard.arn
}

output "security_group_id" {
  value = aws_security_group.alb.id
}

output "alb_arn" {
  value = aws_lb.this.arn
}

output "alb_arn_suffix" {
  value = aws_lb.this.arn_suffix
}

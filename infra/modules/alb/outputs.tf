output "target_group_arn" {
  value = aws_lb_target_group.sammy_tg.arn
}

output "alb_dns_name" {
  value = aws_lb.sammy_alb.dns_name
}

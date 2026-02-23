output "vpc_id" {
  value = aws_vpc.game_vpc.id
}

output "accelerator_ips" {
  value = length(aws_globalaccelerator_accelerator.game_accel) > 0 ? aws_globalaccelerator_accelerator.game_accel[0].ip_sets[0].ip_addresses : []
}

output "alb_dns_name" {
  value = aws_lb.game_alb.dns_name
}

output "alb_arn" {
  value = aws_lb.game_alb.arn
}

output "alb_zone_id" {
  value = aws_lb.game_alb.zone_id
}

output "target_group_arn" {
  value = aws_lb_target_group.game_tg.arn
}

output "public_subnet_ids" {
  value       = aws_subnet.public[*].id
  description = "IDs das subnets públicas para o Fargate Service"
}

output "ecs_security_group_id" {
  value       = aws_security_group.ecs_sg.id
  description = "Security Group para as ECS tasks"
}

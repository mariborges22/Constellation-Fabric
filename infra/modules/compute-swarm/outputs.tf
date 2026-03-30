output "asg_name" {
  value = aws_autoscaling_group.swarm.name
}

output "nakama_repository_url" {
  value = aws_ecr_repository.nakama.repository_url
}

output "swarm_node_role_arn" {
  value = aws_iam_role.swarm_node_role.arn
}

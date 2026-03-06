output "repository_url_auth" {
  value = aws_ecr_repository.auth.repository_url
}

output "repository_url_combat" {
  value = aws_ecr_repository.combat.repository_url
}

output "repository_url_event_publisher" {
  value = aws_ecr_repository.event_publisher.repository_url
}

output "ecs_cluster_id" {
  value = aws_ecs_cluster.game.id
}

output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution_role.arn
}

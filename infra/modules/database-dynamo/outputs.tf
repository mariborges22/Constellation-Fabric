output "player_state_table_arn" {
  value = aws_dynamodb_table.player_state.arn
}

output "combat_logs_table_arn" {
  value = aws_dynamodb_table.combat_logs.arn
}

output "player_state_table_name" {
  value = aws_dynamodb_table.player_state.name
}

output "combat_logs_table_name" {
  value = aws_dynamodb_table.combat_logs.name
}

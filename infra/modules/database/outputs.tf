output "db_instance_endpoint" {
  value = aws_db_instance.game_db.endpoint
}

output "db_instance_address" {
  value = aws_db_instance.game_db.address
}

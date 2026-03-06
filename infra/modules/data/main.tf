resource "aws_kinesis_stream" "combat_events" {
  name             = "${var.project_name}-combat-events"
  shard_count      = 1
  retention_period = 24

  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Name = "${var.project_name}-combat-events-stream"
  }
}

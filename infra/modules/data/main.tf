terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_kinesis_stream" "combat_events" {
  name             = var.region == "us-east-1" ? "${var.project_name}-combat-events" : "${var.project_name}-combat-events-${var.region}"
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

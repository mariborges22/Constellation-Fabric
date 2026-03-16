terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_kms_key" "kinesis" {
  description             = "KMS key for Kinesis encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-kinesis-kms"
  }
}

resource "aws_kms_alias" "kinesis" {
  name          = "alias/${var.project_name}-${var.environment}-kinesis"
  target_key_id = aws_kms_key.kinesis.key_id
}

resource "aws_kinesis_stream" "combat_events" {
  name             = var.region == "us-east-1" ? "${var.project_name}-${var.environment}-combat-events" : "${var.project_name}-${var.environment}-combat-events-${var.region}"
  shard_count      = 1
  retention_period = 24

  encryption_type = "KMS"
  kms_key_id      = aws_kms_key.kinesis.arn

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

terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_dynamodb_table" "player_state" {
  name             = "${var.project_name}-${var.environment}-player-state"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "pk"
  range_key        = "sk"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "email"
    type = "S"
  }

  attribute {
    name = "username"
    type = "S"
  }

  global_secondary_index {
    name               = "gsi1"
    hash_key           = "email"
    range_key          = "pk"
    projection_type    = "ALL"
  }

  global_secondary_index {
    name               = "gsi2"
    hash_key           = "username"
    range_key          = "pk"
    projection_type    = "ALL"
  }

  # Replica managed externally to avoid token issues
  
  tags = {
    Environment = var.environment
    Project     = var.project_name
    Vision      = "Equestria-Odyssey"
  }
}

resource "aws_dynamodb_table" "combat_logs" {
  name         = "${var.project_name}-${var.environment}-combat-logs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "match_id"
  range_key    = "timestamp"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "match_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  # Replica managed externally

  tags = {
    Environment = var.environment
    Project     = var.project_name
    Type        = "Logs"
  }
}

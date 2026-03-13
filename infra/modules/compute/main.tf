terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_ecr_repository" "auth" {
  name                 = var.region == "us-east-1" ? "constellation-auth" : "constellation-auth-${var.region}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.region == "us-east-1" ? "${var.project_name}-auth-repo" : "${var.project_name}-auth-repo-${var.region}"
  }

  lifecycle {
    # prevent_destroy = true # Comentado para permitir o rename/migração sem erro
  }
}

resource "aws_ecr_repository" "combat" {
  name                 = var.region == "us-east-1" ? "constellation-combat" : "constellation-combat-${var.region}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.region == "us-east-1" ? "${var.project_name}-combat-repo" : "${var.project_name}-combat-repo-${var.region}"
  }

  lifecycle {
    # prevent_destroy = true # Comentado para permitir o rename/migração sem erro
  }
}

resource "aws_ecr_repository" "event_publisher" {
  name                 = var.region == "us-east-1" ? "constellation-event-publisher" : "constellation-event-publisher-${var.region}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.region == "us-east-1" ? "${var.project_name}-event-publisher-repo" : "${var.project_name}-event-publisher-repo-${var.region}"
  }

  lifecycle {
    # prevent_destroy = true # Comentado para permitir o rename/migração sem erro
  }
}

resource "aws_ecr_repository" "player_state" {
  name                 = var.region == "us-east-1" ? "constellation-player_state" : "constellation-player_state-${var.region}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = var.region == "us-east-1" ? "${var.project_name}-player_state-repo" : "${var.project_name}-player_state-repo-${var.region}"
  }

  lifecycle {
    # prevent_destroy = true # Comentado para permitir o rename/migração sem erro
  }
}

# ============================================================
# ECS Cluster
# ============================================================
resource "aws_ecs_cluster" "game" {
  name = var.region == "us-east-1" ? "${var.project_name}-cluster" : "${var.project_name}-cluster-${var.region}"

  lifecycle {
    # prevent_destroy = true # Comentado para permitir o rename/migração sem erro
  }
}

# IAM Execution Role (allows Fargate to pull ECR + read Secrets Manager)
resource "aws_iam_role" "ecs_execution_role" {
  name = var.region == "us-east-1" ? "${var.project_name}-ecs-execution-role" : "${var.project_name}-ecs-execution-role-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_base" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Grant ECS access to the Cloudflare tunnel token in Secrets Manager
resource "aws_iam_role_policy" "ecs_secrets_access" {
  name = "cloudflare-tunnel-secret-access"
  role = aws_iam_role.ecs_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [var.tunnel_secret_arn]
    }]
  })
}

# ECS Task Role (allows the application to interact with AWS services like X-Ray)
resource "aws_iam_role" "ecs_task_role" {
  name = var.region == "us-east-1" ? "${var.project_name}-ecs-task-role" : "${var.project_name}-ecs-task-role-${var.region}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ecs_task_monitoring" {
  name = "ecs-task-monitoring-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
        Resource = [var.kinesis_stream_arn]
      }
    ]
  })
}

# ============================================================
# CloudWatch Log Groups for ECS containers
# ============================================================
resource "aws_cloudwatch_log_group" "auth" {
  name              = "/ecs/${var.project_name}-auth"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "cloudflared" {
  name              = "/ecs/${var.project_name}-cloudflared"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "combat" {
  name              = "/ecs/${var.project_name}-combat"
  retention_in_days = 7
}

# ============================================================
# ECS Task Definition — Auth app + cloudflared sidecar
# ============================================================
resource "aws_ecs_task_definition" "auth" {
  family                   = "${var.project_name}-auth"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "auth"
      image     = "${aws_ecr_repository.auth.repository_url}:staging"
      essential = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      command      = ["auth"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.auth.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "cloudflared"
      image     = "cloudflare/cloudflared:latest"
      essential = false
      command   = ["tunnel", "--no-autoupdate", "run"]
      secrets   = [{
        name      = "TUNNEL_TOKEN"
        valueFrom = var.tunnel_secret_arn
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.cloudflared.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ============================================================
# ECS Task Definition — Player State
# ============================================================
resource "aws_ecs_task_definition" "player_state" {
  family                   = "${var.project_name}-player_state"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "player-state"
      image     = "${aws_ecr_repository.player_state.repository_url}:staging"
      essential = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      command      = ["player-state"]
      environment = [
        { name = "DATABASE_URL", value = "postgresql://postgres:${var.db_password}@${var.db_endpoint}/constellation" },
        { name = "PORT", value = "8080" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.player_state.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}


resource "aws_cloudwatch_log_group" "player_state" {
  name              = "/ecs/${var.project_name}-player_state"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "postgres" {
  name              = "/ecs/${var.project_name}-postgres"
  retention_in_days = 7
}

# ============================================================
# ECS Task Definition — Combat
# ============================================================
resource "aws_ecs_task_definition" "combat" {
  family                   = "${var.project_name}-combat"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "combat"
      image     = "${aws_ecr_repository.combat.repository_url}:staging"
      essential = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
      command      = ["combat"]
      environment = [
        { name = "PLAYER_STATE_API", value = "http://player-state.local:8080/api/v1/players" },
        { name = "KINESIS_STREAM_NAME", value = var.kinesis_stream_name },
        { name = "PORT", value = "8080" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.combat.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ============================================================
# ECS Fargate Service
# ============================================================
resource "aws_ecs_service" "auth" {
  name            = "auth-service"
  cluster         = aws_ecs_cluster.game.id
  task_definition = aws_ecs_task_definition.auth.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.auth_tg_arn
    container_name   = "auth"
    container_port   = 8080
  }

  # lifecycle {
  #   ignore_changes = [task_definition] # CI/CD manages deployments
  # }
}

resource "aws_ecs_service" "player_state" {
  name            = "player-state-service"
  cluster         = aws_ecs_cluster.game.id
  task_definition = aws_ecs_task_definition.player_state.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.player_state_tg_arn
    container_name   = "player-state"
    container_port   = 8080
  }

  # lifecycle {
  #   ignore_changes = [task_definition]
  # }
}


resource "aws_ecs_service" "combat" {
  name            = "combat-service"
  cluster         = aws_ecs_cluster.game.id
  task_definition = aws_ecs_task_definition.combat.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.combat_tg_arn
    container_name   = "combat"
    container_port   = 8080
  }

  # lifecycle {
  #   ignore_changes = [task_definition]
  # }
}

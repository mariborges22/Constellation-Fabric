resource "aws_ecr_repository" "auth" {
  name                 = "constellation-auth"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-auth-repo"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository" "combat" {
  name                 = "constellation-combat"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-combat-repo"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository" "event_publisher" {
  name                 = "constellation-event-publisher"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-event-publisher-repo"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecr_repository" "player_state" {
  name                 = "constellation-player_state"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.project_name}-player_state-repo"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# ============================================================
# ECS Cluster
# ============================================================
resource "aws_ecs_cluster" "game" {
  name = "${var.project_name}-cluster"

  lifecycle {
    prevent_destroy = true
  }
}

# IAM Execution Role (allows Fargate to pull ECR + read Secrets Manager)
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.project_name}-ecs-execution-role"

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
  name = "${var.project_name}-ecs-task-role"

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
          "awslogs-region"        = "us-east-1"
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
          "awslogs-region"        = "us-east-1"
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
        { name = "DATABASE_URL", value = "postgresql://postgres:${var.db_password}@postgres.local:5432/constellation" },
        { name = "PORT", value = "8080" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.player_state.name
          "awslogs-region"        = "us-east-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ============================================================
# ECS Task Definition — Postgres
# ============================================================
resource "aws_ecs_task_definition" "postgres" {
  family                   = "${var.project_name}-postgres"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "postgres"
      image     = "postgres:15-bookworm"
      essential = true
      portMappings = [{ containerPort = 5432, protocol = "tcp" }]
      environment = [
        { name = "POSTGRES_USER", value = "postgres" },
        { name = "POSTGRES_PASSWORD", value = var.db_password },
        { name = "POSTGRES_DB", value = "constellation" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.postgres.name
          "awslogs-region"        = "us-east-1"
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
        { name = "PORT", value = "8080" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.combat.name
          "awslogs-region"        = "us-east-1"
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

resource "aws_ecs_service" "postgres" {
  name            = "postgres-service"
  cluster         = aws_ecs_cluster.game.id
  task_definition = aws_ecs_task_definition.postgres.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  service_registries {
    registry_arn = var.postgres_discovery_arn
  }
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

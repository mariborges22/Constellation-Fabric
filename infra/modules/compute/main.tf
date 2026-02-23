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

  container_definitions = jsonencode([
    {
      name      = "auth"
      image     = "${aws_ecr_repository.auth.repository_url}:staging"
      essential = true
      portMappings = [{ containerPort = 8080, protocol = "tcp" }]
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

  lifecycle {
    ignore_changes = [task_definition] # CI/CD manages deployments
  }
}

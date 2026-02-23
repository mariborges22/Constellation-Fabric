terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0.0-beta"
    }
  }
}

# Data source for AZs
data "aws_availability_zones" "available" {
  state = "available"
}

# Configuração de VPC Regional
resource "aws_vpc" "game_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  
  tags = { Name = "${var.project_name}-${var.region}-vpc" }

  lifecycle {
    prevent_destroy = true
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.game_vpc.id
  tags   = { Name = "${var.project_name}-${var.region}-igw" }
}

# Subnets Públicas (Para o ALB)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.game_vpc.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 100) # 100, 101...
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-${count.index}" }
}

# Subnets Privadas (Onde o backend Rust vai rodar)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.game_vpc.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags              = { Name = "${var.project_name}-private-${count.index}" }
}

# Roteamento Público
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.game_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Group para o ALB
resource "aws_security_group" "alb_sg" {
  name        = substr("${var.project_name}-${var.region}-alb-sg", 0, 32)
  description = "Permitir trafego HTTP/HTTPS"
  vpc_id      = aws_vpc.game_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group para as ECS tasks (Fargate + cloudflared sidecar)
resource "aws_security_group" "ecs_sg" {
  name        = substr("${var.project_name}-${var.region}-ecs-sg", 0, 32)
  description = "ECS tasks: recebe do ALB na 8080, libera todo egress para ECR/Cloudflare"
  vpc_id      = aws_vpc.game_vpc.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Só o ALB pode chamar o container
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Necessário para ECR pull, Secrets Manager e Cloudflare Tunnel
  }
}

# Application Load Balancer (ALB)
resource "aws_lb" "game_alb" {
  # Limit name to 32 characters
  name               = substr("${var.project_name}-${var.region}-alb", 0, 32)
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  lifecycle {
    prevent_destroy = true
  }
}

# Health Check de 30s (SRE requirement)
resource "aws_lb_target_group" "game_tg" {
  # Limit name to 32 characters
  name     = substr("${var.project_name}-${var.region}-tg", 0, 32)
  port     = 8080 # Porta do backend Rust
  protocol = "HTTP"
  vpc_id   = aws_vpc.game_vpc.id

  health_check {
    enabled             = true
    interval            = 30 # Check a cada 30s conforme solicitado
    path                = "/health"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2 # Failover rápido
  }
}

# AWS Global Accelerator (Ponto de Entrada Único)
resource "aws_globalaccelerator_accelerator" "game_accel" {
  count           = var.enable_global_accelerator ? 1 : 0
  name            = substr("${var.project_name}-${var.region}-accel", 0, 32)
  ip_address_type = "IPV4"
  enabled         = true

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_globalaccelerator_listener" "game_listener" {
  count           = var.enable_global_accelerator ? 1 : 0
  accelerator_arn = aws_globalaccelerator_accelerator.game_accel[0].id
  client_affinity = "NONE"
  protocol        = "TCP"

  port_range {
    from_port = 443
    to_port   = 443
  }
}

# ============================================================
# ALB LISTENER - HTTP ONLY (CloudFlare faz HTTPS)
# ============================================================
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.game_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.game_tg.arn
  }
}

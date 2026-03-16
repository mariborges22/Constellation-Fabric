terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}

resource "aws_db_subnet_group" "db" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Permitir entrada do ECS na porta 5432"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ecs_sg_id]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.secondary_vpc_cidr != "" ? [var.secondary_vpc_cidr] : []
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = {
    Name = "${var.project_name}-rds-kms"
  }
}

resource "aws_kms_alias" "rds" {
  name          = "alias/${var.project_name}-${var.environment}-rds"
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_db_instance" "game_db" {
  identifier           = "${var.project_name}-${var.environment}-db"
  allocated_storage     = 20
  storage_type         = "gp3"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = "db.t3.micro"
  db_name              = "constellation"
  username             = "postgres"
  password             = var.db_password
  parameter_group_name = "default.postgres15"
  skip_final_snapshot  = true # Só para staging/dev
  publicly_accessible  = false
  db_subnet_group_name = aws_db_subnet_group.db.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-instance"
  }
}

resource "aws_secretsmanager_secret" "db_url" {
  name        = "${var.project_name}-${var.environment}-db-url-v2" # Nome v2 para desvincular da chave KMS deletada
  description = "DATABASE_URL para serviços do Constellation Fabric"
  kms_key_id  = aws_kms_key.rds.arn

  tags = {
    Name = "${var.project_name}-${var.environment}-database-url"
  }
}

resource "aws_secretsmanager_secret_version" "db_url" {
  secret_id     = aws_secretsmanager_secret.db_url.id
  secret_string = "postgresql://postgres:${var.db_password}@${aws_db_instance.game_db.endpoint}/constellation"
}


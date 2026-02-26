variable "project_name" {
  type        = string
  description = "Nome do projeto"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Lista de subnet IDs públicas para o Fargate Service"
}

variable "security_group_id" {
  type        = string
  description = "Security Group para as tasks do ECS"
}

variable "tunnel_secret_arn" {
  type        = string
  description = "ARN do Secrets Manager secret com o token do Cloudflare Tunnel"
  sensitive   = true
}

variable "player_state_tg_arn" {
  type        = string
  description = "ARN do Target Group para o Player State"
}

variable "postgres_discovery_arn" {
  type        = string
  description = "ARN do Service Discovery para o Postgres"
}

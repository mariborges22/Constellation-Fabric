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

variable "auth_tg_arn" {
  type        = string
  description = "ARN do Target Group para o Auth Service"
}

variable "player_state_tg_arn" {
  type        = string
  description = "ARN do Target Group para o Player State"
}

variable "combat_tg_arn" {
  type        = string
  description = "ARN do Target Group para o Combat Engine"
}

variable "db_endpoint" {
  type        = string
  description = "RDS Instance endpoint"
  default     = ""
}

variable "db_password" {
  type        = string
  description = "Senha do banco de dados"
  sensitive   = true
}

variable "kinesis_stream_name" {
  type        = string
  description = "Nome do Kinesis Stream para eventos de combate"
  default     = ""
}

variable "kinesis_stream_arn" {
  type        = string
  description = "ARN do Kinesis Stream para permissões IAM"
  default     = ""
}

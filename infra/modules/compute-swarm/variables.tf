variable "project_name" {
  type        = string
  description = "Nome do projeto"
}

variable "environment" {
  type        = string
  description = "Ambiente (staging/production)"
  default     = "staging"
}

variable "region" {
  type        = string
  description = "AWS Region for this deployment"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Lista de subnet IDs para as instâncias EC2"
}

variable "security_group_id" {
  type        = string
  description = "Security Group para o cluster Swarm"
}

variable "instance_type" {
  type        = string
  default     = "t3.medium"
  description = "Tipo da instância EC2"
}

variable "image_tag" {
  type        = string
  default     = "latest"
  description = "Tag das imagens Docker (para referência em scripts se necessário)"
}

variable "tunnel_secret_arn" {
  type        = string
  description = "ARN do Secrets Manager com o token do Cloudflare Tunnel"
  default     = ""
}

variable "jwt_secret_arn" {
  type        = string
  description = "ARN do Secrets Manager com as chaves JWT"
  default     = ""
}

variable "rds_kms_arn" {
  type        = string
  description = "ARN da chave KMS para RDS"
  default     = ""
}

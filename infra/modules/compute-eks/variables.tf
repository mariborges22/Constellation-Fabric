variable "project_name" {
  description = "Nome do projeto para prefixo de recursos"
  type        = string
}

variable "environment" {
  description = "Ambiente (staging/production)"
  type        = string
}

variable "region" {
  description = "Região da AWS"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID onde o EKS será implantado"
  type        = string
}

variable "subnet_ids" {
  description = "Lista de subnets privadas para os nodes"
  type        = list(string)
}

variable "instance_types" {
  description = "Tipos de instância para o node group"
  type        = list(string)
  default     = ["t3.medium"]
}

variable "desired_size" {
  description = "Quantidade desejada de nodes"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Quantidade máxima de nodes"
  type        = number
  default     = 2
}

variable "min_size" {
  description = "Quantidade mínima de nodes"
  type        = number
  default     = 1
}

variable "player_state_table_arn" {
  description = "ARN da tabela DynamoDB de estado do jogador"
  type        = string
}

variable "combat_logs_table_arn" {
  description = "ARN da tabela DynamoDB de logs de combate"
  type        = string
}

variable "github_actions_role_arn" {
  description = "ARN da Role do GitHub Actions para permissão no EKS"
  type        = string
}

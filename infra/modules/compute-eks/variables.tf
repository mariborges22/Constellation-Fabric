variable "project_name" {
  type        = string
  description = "Nome do projeto"
}

variable "environment" {
  type        = string
  description = "Ambiente (staging/production)"
}

variable "region" {
  type        = string
  description = "AWS Region"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets para o cluster (geralmente privadas)"
}

variable "instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "Tipos de instância para o Node Group"
}

variable "desired_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 3
}

variable "min_size" {
  type    = number
  default = 1
}

variable "image_tag" {
  type    = string
  default = "latest"
}

variable "player_state_table_arn" {
  type        = string
  description = "ARN da tabela DynamoDB player-state"
  default     = ""
}

variable "combat_logs_table_arn" {
  type        = string
  description = "ARN da tabela DynamoDB combat-logs"
  default     = ""
}

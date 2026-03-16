variable "project_name" {
  type        = string
  description = "Nome do projeto (usado para nomear recursos)"
}

variable "environment" {
  type        = string
  description = "Ambiente (staging/production)"
  default     = "staging"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "Região AWS onde os recursos serão criados"
}

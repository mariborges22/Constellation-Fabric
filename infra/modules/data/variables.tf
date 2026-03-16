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
  type = string
}

variable "region" {
  type        = string
  description = "AWS Region principal"
  default     = "us-east-1"
}

variable "project_name" {
  type        = string
  description = "Nome do projeto"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block para a VPC"
}

variable "db_password" {
  type        = string
  description = "Senha do banco de dados RDS"
  sensitive   = true
}

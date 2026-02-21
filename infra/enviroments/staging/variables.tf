variable "project_name" {
  type        = string
  description = "Nome do projeto"
}

variable "region" {
  type        = string
  description = "Região da AWS"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR da VPC"
}

variable "domain_name" {
  type        = string
  description = "Domínio principal"
  default     = "constellation-fabric.com"
}

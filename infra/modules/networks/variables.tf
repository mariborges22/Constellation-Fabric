variable "region" {
  type        = string
  description = "Região alvo definida pelo meta-argumento do Provider 6.0"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "project_name" {
  type = string
}

variable "enable_global_accelerator" {
  type    = bool
  default = false
}
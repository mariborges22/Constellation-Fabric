variable "project_name" { type = string }

variable "environment" {
  type        = string
  description = "Ambiente (staging/production)"
  default     = "staging"
}
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "ecs_sg_id" { type = string }
variable "db_password" { type = string }
variable "region" { type = string }

variable "secondary_vpc_cidr" {
  type    = string
  default = ""
}

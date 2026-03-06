variable "project_name" {
  type = string
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "ecs_cluster_id" {
  type = string
}

variable "ecs_execution_role_arn" {
  type = string
}

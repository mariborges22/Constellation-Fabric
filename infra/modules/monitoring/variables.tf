variable "project_name" {
  type = string
}

variable "environment" {
  type        = string
  description = "Ambiente (staging/production)"
  default     = "staging"
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

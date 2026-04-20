variable "project_name" { type = string }
variable "environment" { type = string }
variable "region" { type = string }

variable "auth_image" { type = string }
variable "combat_image" { type = string }

variable "player_state_table_name" { type = string }
variable "combat_logs_table_name" { type = string }

variable "auth_irsa_role_arn" { type = string }
variable "combat_irsa_role_arn" { type = string }

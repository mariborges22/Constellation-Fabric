variable "project_name" {
  type        = string
  description = "Nome do projeto para identificação dos recursos"
}

variable "environment" {
  type        = string
  description = "Ambiente (staging/production)"
  default     = "staging"
}

variable "github_repo" {
  type        = string
  description = "Seu repositório no formato 'usuario/repo' para restringir o acesso"
}

variable "github_thumbprint" {
  type        = string
  default     = "6938fd4d98bab03faadb97b34396831e3780aea1"
}

variable "create_global_resources" {
  type        = bool
  description = "Define se recursos globais (IAM OIDC, Budgets) devem ser criados"
  default     = true
}
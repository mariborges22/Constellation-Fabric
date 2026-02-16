ariable "project_name" {
  type        = string
  description = "Nome do projeto para identificação dos recursos"
}

variable "github_repo" {
  type        = string
  description = "Seu repositório no formato 'usuario/repo' para restringir o acesso [5]"
}

variable "github_thumbprint" {
  type        = string
  default     = "6938fd4d98bab03faadb97b34396831e3780aea1" # Thumbprint padrão do GitHub [5]
}
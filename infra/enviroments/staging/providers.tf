terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0.0-beta" # Essencial para o multi-region dinâmico [1]
    }
  }
}

provider "aws" {
  # Região padrão (pode ser a us-east-1)
  region = "us-east-1"
}
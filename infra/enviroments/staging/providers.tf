terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0.0-beta" # Tech Lead's requirement
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.27"
    }
  }
}

# Regional Providers with standard naming
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = "eu-west-1"
}

provider "aws" {
  region = "us-east-1" # Default
}

# Helm and Kubernetes Providers needed for EKS addons
provider "kubernetes" {
  host                   = module.compute_eks_us.cluster_endpoint
  cluster_ca_certificate = base64decode(module.compute_eks_us.cluster_certificate_authority_data)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    args        = ["eks", "get-token", "--cluster-name", module.compute_eks_us.cluster_name]
    command     = "aws"
  }
}

provider "helm" {
  kubernetes {
    host                   = module.compute_eks_us.cluster_endpoint
    cluster_ca_certificate = base64decode(module.compute_eks_us.cluster_certificate_authority_data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.compute_eks_us.cluster_name]
      command     = "aws"
    }
  }
}
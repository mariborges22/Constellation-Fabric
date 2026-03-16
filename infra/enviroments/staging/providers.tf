terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0.0-beta" # Tech Lead's requirement
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
terraform {
  backend "s3" {
    bucket         = "constellation-fabric-tfstate-721529235452"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile = true
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "secondary"
  region = "eu-west-1"
}

provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket         = "seu-projeto-terraform-state-staging" # Nome do bucket que você criará
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock-staging"             # Para evitar conflitos de escrita
    encrypt        = true
  }
}
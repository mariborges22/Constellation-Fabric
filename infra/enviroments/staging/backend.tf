terraform {
  backend "s3" {
    bucket         = "constellation-fabrick-bucket" # Nome do bucket que você criará
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile = true             # Para evitar conflitos de escrita
    encrypt        = true
  }
}
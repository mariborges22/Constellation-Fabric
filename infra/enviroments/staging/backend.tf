terraform {
  backend "s3" {
    bucket         = "constellation-fabric-tfstate-721529235452" # Bucket único para a nova conta
    key            = "staging/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile = true             # Para evitar conflitos de escrita
    encrypt        = true
  }
}
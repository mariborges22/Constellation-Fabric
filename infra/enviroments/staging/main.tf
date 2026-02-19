module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  github_repo  = "mariborges22/constellation-fabric"
}

module "networks_us" {
  source = "../../modules/networks"
  providers = {
    aws = aws.us_east_1
  }

  project_name = var.project_name
  region       = "us-east-1"
  vpc_cidr     = "10.0.0.0/16"
}

module "networks_eu" {
  source = "../../modules/networks"
  providers = {
    aws = aws.eu_west_1
  }

  project_name = var.project_name
  region       = "eu-west-1"
  vpc_cidr     = "10.1.0.0/16"
}

module "monitoring" {
  source = "../../modules/monitoring"

  project_name = var.project_name
  region       = var.region
}

module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
}

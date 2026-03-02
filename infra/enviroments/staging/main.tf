module "security" {
  source = "../../modules/security"

  project_name = var.project_name
  github_repo  = "mariborges22/Constellation-Fabric"
}

module "networks_us" {
  source = "../../modules/networks"
  providers = {
    aws = aws.primary
  }

  project_name = var.project_name
  region       = "us-east-1"
  vpc_cidr     = "10.0.0.0/16"
}

module "networks_eu" {
  source = "../../modules/networks"
  providers = {
    aws = aws.secondary
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

  project_name              = var.project_name
  subnet_ids                = module.networks_us.public_subnet_ids
  security_group_id         = module.networks_us.ecs_security_group_id
  tunnel_secret_arn         = module.https.tunnel_secret_arn
  player_state_tg_arn      = module.networks_us.player_state_tg_arn
  combat_tg_arn            = module.networks_us.combat_tg_arn
  postgres_discovery_arn    = module.networks_us.postgres_discovery_arn
  db_password               = var.db_password
}

module "https" {
  source = "../../modules/https"

  project_name = var.project_name
  aws_region   = var.region
}


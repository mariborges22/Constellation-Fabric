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

  project_name           = var.project_name
  region                 = var.region
  vpc_id                = module.networks_us.vpc_id
  subnet_ids             = module.networks_us.public_subnet_ids
  security_group_id      = module.networks_us.ecs_security_group_id
  ecs_cluster_id        = module.compute.ecs_cluster_id
  ecs_execution_role_arn = module.compute.ecs_execution_role_arn
}

module "database" {
  source = "../../modules/database"

  project_name       = var.project_name
  vpc_id             = module.networks_us.vpc_id
  private_subnet_ids = module.networks_us.public_subnet_ids # Usando public por enquanto para simplificar acesso se necessário, mas RDS SG protege
  ecs_sg_id          = module.networks_us.ecs_security_group_id
  db_password        = var.db_password
  region             = var.region
}

module "compute" {
  source = "../../modules/compute"

  project_name              = var.project_name
  subnet_ids                = module.networks_us.public_subnet_ids
  security_group_id         = module.networks_us.ecs_security_group_id
  auth_tg_arn               = module.networks_us.target_group_arn
  tunnel_secret_arn         = module.https.tunnel_secret_arn
  player_state_tg_arn      = module.networks_us.player_state_tg_arn
  combat_tg_arn            = module.networks_us.combat_tg_arn
  db_password               = var.db_password
  db_endpoint               = module.database.db_instance_endpoint
  kinesis_stream_name       = module.data.kinesis_stream_name
  kinesis_stream_arn        = module.data.kinesis_stream_arn
}

module "data" {
  source = "../../modules/data"

  project_name = var.project_name
  region       = var.region
}

module "https" {
  source = "../../modules/https"

  project_name = var.project_name
  aws_region   = var.region
}

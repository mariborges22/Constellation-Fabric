module "security" {
  source = "../../modules/security"

  project_name            = var.project_name
  environment             = "production"
  create_global_resources = false # Não recriar OIDC/Budgets em Prod
  github_repo             = "mariborges22/Constellation-Fabric"
}

module "networks_us" {
  source = "../../modules/networks"
  providers = {
    aws = aws.primary
  }

  project_name = var.project_name
  environment  = "production"
  region       = "us-east-1"
  vpc_cidr     = var.vpc_cidr # 10.2.0.0/16
}

module "networks_eu" {
  source = "../../modules/networks"
  providers = {
    aws = aws.secondary
  }

  project_name = var.project_name
  environment  = "production"
  region       = "eu-west-1"
  vpc_cidr     = "10.3.0.0/16" # Produção EU
}


module "database_global" {
  source = "../../modules/database-dynamo"
  providers = {
    aws = aws.primary
  }

  project_name = var.project_name
  environment  = "production"
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = "production"
}

module "compute_eks_us" {
  source = "../../modules/compute-eks"
  providers = {
    aws = aws.primary
  }

  project_name   = var.project_name
  environment    = "production"
  region         = "us-east-1"
  vpc_id         = module.networks_us.vpc_id
  subnet_ids     = module.networks_us.private_subnet_ids
  instance_types = ["t3.medium"]
  desired_size   = 2
  max_size       = 5
  min_size       = 1
  player_state_table_arn = module.database_global.player_state_table_arn
  combat_logs_table_arn  = module.database_global.combat_logs_table_arn
}

module "compute_eks_eu" {
  source = "../../modules/compute-eks"
  providers = {
    aws = aws.secondary
  }

  project_name   = var.project_name
  environment    = "production"
  region         = "eu-west-1"
  vpc_id         = module.networks_eu.vpc_id
  subnet_ids     = module.networks_eu.private_subnet_ids
  instance_types = ["t3.medium"]
  desired_size   = 1
  max_size       = 3
  min_size       = 1
  player_state_table_arn = module.database_global.player_state_table_arn
  combat_logs_table_arn  = module.database_global.combat_logs_table_arn
}

module "https" {
  source = "../../modules/https"

  project_name = var.project_name
  environment  = "production"
  aws_region   = var.region
}


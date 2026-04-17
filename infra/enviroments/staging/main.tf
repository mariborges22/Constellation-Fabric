module "security" {
  source = "../../modules/security"

  project_name            = var.project_name
  environment             = "staging"
  create_global_resources = true
  github_repo             = "mariborges22/Constellation-Fabric"
}

module "compute_eks_us" {
  source = "../../modules/compute-eks"
  providers = {
    aws = aws.primary
  }

  project_name   = var.project_name
  environment    = "staging"
  region         = "us-east-1"
  vpc_id         = module.networks_us.vpc_id
  subnet_ids     = module.networks_us.private_subnet_ids
  instance_types = ["t3.medium"]
  desired_size   = 1
  max_size       = 2
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
  environment    = "staging"
  region         = "eu-west-1"
  vpc_id         = module.networks_eu.vpc_id
  subnet_ids     = module.networks_eu.private_subnet_ids
  instance_types = ["t3.medium"]
  desired_size   = 1
  max_size       = 2
  min_size       = 1
  player_state_table_arn = module.database_global.player_state_table_arn
  combat_logs_table_arn  = module.database_global.combat_logs_table_arn
}

module "networks_us" {
  source = "../../modules/networks"
  providers = {
    aws = aws.primary
  }

  project_name = var.project_name
  environment  = "staging"
  region       = "us-east-1"
  vpc_cidr     = "10.0.0.0/16"
}

module "networks_eu" {
  source = "../../modules/networks"
  providers = {
    aws = aws.secondary
  }

  project_name = var.project_name
  environment  = "staging"
  region       = "eu-west-1"
  vpc_cidr     = "10.1.0.0/16"
}


# Novo Módulo de Banco de Dados Global (DynamoDB)
module "database_global" {
  source = "../../modules/database-dynamo"
  providers = {
    aws = aws.primary
  }

  project_name = var.project_name
  environment  = "staging"
}

# Replicas gerenciadas explicitamente com o provider regional para evitar erros de Token
resource "aws_dynamodb_table_replica" "player_state_eu" {
  provider         = aws.secondary
  global_table_arn = module.database_global.player_state_table_arn
}

resource "aws_dynamodb_table_replica" "combat_logs_eu" {
  provider         = aws.secondary
  global_table_arn = module.database_global.combat_logs_table_arn
}

module "ecr" {
  source = "../../modules/ecr"

  project_name = var.project_name
  environment  = "staging"
}

module "https" {
  source = "../../modules/https"

  project_name = var.project_name
  environment  = "staging"
  aws_region   = var.region
}

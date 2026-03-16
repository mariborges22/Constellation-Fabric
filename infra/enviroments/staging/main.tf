module "security" {
  source = "../../modules/security"

  project_name            = var.project_name
  environment             = "staging"
  create_global_resources = true
  github_repo             = "mariborges22/Constellation-Fabric"
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

module "monitoring" {
  source = "../../modules/monitoring"

  project_name           = var.project_name
  environment            = "staging"
  region                 = var.region
  vpc_id                = module.networks_us.vpc_id
  subnet_ids             = module.networks_us.public_subnet_ids
  security_group_id      = module.networks_us.ecs_security_group_id
  ecs_cluster_id        = module.compute_us.ecs_cluster_id
  ecs_execution_role_arn = module.compute_us.ecs_execution_role_arn
}

module "database" {
  source = "../../modules/database"

  project_name       = var.project_name
  environment        = "staging"
  vpc_id             = module.networks_us.vpc_id
  private_subnet_ids = module.networks_us.public_subnet_ids 
  ecs_sg_id          = module.networks_us.ecs_security_group_id
  db_password        = var.db_password
  region             = var.region
  secondary_vpc_cidr = module.networks_eu.vpc_cidr
}

module "compute_us" {
  source = "../../modules/compute"
  providers = {
    aws = aws.primary
  }

  project_name        = var.project_name
  environment         = "staging"
  region              = "us-east-1"
  subnet_ids          = module.networks_us.public_subnet_ids
  security_group_id   = module.networks_us.ecs_security_group_id
  auth_tg_arn         = module.networks_us.target_group_arn
  tunnel_secret_arn   = module.https.tunnel_secret_arn
  player_state_tg_arn = module.networks_us.player_state_tg_arn
  combat_tg_arn       = module.networks_us.combat_tg_arn
  db_password         = var.db_password
  db_endpoint         = module.database.db_instance_endpoint
  db_secret_arn       = module.database.db_secret_arn
  jwt_secret_arn      = module.security.jwt_secret_arn
  kinesis_stream_name = module.data_us.kinesis_stream_name
  kinesis_stream_arn  = module.data_us.kinesis_stream_arn
  rds_kms_arn         = module.database.rds_kms_arn
  image_tag           = "staging"
}

module "compute_eu" {
  source = "../../modules/compute"
  providers = {
    aws = aws.secondary
  }

  project_name        = var.project_name
  environment         = "staging"
  region              = "eu-west-1"
  subnet_ids          = module.networks_eu.public_subnet_ids
  security_group_id   = module.networks_eu.ecs_security_group_id
  auth_tg_arn         = module.networks_eu.target_group_arn
  tunnel_secret_arn   = module.https.tunnel_secret_arn
  player_state_tg_arn = module.networks_eu.player_state_tg_arn
  combat_tg_arn       = module.networks_eu.combat_tg_arn
  db_password         = var.db_password
  db_endpoint         = module.database.db_instance_endpoint 
  db_secret_arn       = module.database.db_secret_arn
  jwt_secret_arn      = module.security.jwt_secret_arn
  kinesis_stream_name = module.data_eu.kinesis_stream_name
  kinesis_stream_arn  = module.data_eu.kinesis_stream_arn
  rds_kms_arn         = module.database.rds_kms_arn
  image_tag           = "staging"
}

module "data_us" {
  source = "../../modules/data"
  providers = {
    aws = aws.primary
  }

  project_name = var.project_name
  environment  = "staging"
  region       = "us-east-1"
}

module "data_eu" {
  source = "../../modules/data"
  providers = {
    aws = aws.secondary
  }

  project_name = var.project_name
  environment  = "staging"
  region       = "eu-west-1"
}

module "https" {
  source = "../../modules/https"

  project_name = var.project_name
  environment  = "staging"
  aws_region   = var.region
}

# ============================================================
# State Migration (Refactoring)
# ============================================================
moved {
  from = module.compute
  to   = module.compute_us
}

moved {
  from = module.data
  to   = module.data_us
}

# ============================================================
# Cross-Region Networking (VPC Peering)
# ============================================================
resource "aws_vpc_peering_connection" "us_eu" {
  provider      = aws.primary
  vpc_id        = module.networks_us.vpc_id
  peer_vpc_id   = module.networks_eu.vpc_id
  peer_region   = "eu-west-1"
  auto_accept   = false

  tags = {
    Name = "${var.project_name}-peering-us-eu"
  }
}

resource "aws_vpc_peering_connection_accepter" "eu_us" {
  provider                  = aws.secondary
  vpc_peering_connection_id = aws_vpc_peering_connection.us_eu.id
  auto_accept               = true

  tags = {
    Name = "${var.project_name}-peering-eu-us"
  }
}

resource "aws_route" "us_to_eu" {
  provider                  = aws.primary
  route_table_id            = module.networks_us.public_route_table_id
  destination_cidr_block     = module.networks_eu.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.us_eu.id
}

resource "aws_route" "eu_to_us" {
  provider                  = aws.secondary
  route_table_id            = module.networks_eu.public_route_table_id
  destination_cidr_block     = module.networks_us.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.us_eu.id
}

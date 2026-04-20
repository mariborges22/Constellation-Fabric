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
  instance_types = ["t4g.medium"]
  desired_size   = 2
  max_size       = 3
  min_size       = 2
  player_state_table_arn = module.database_global.player_state_table_arn
  combat_logs_table_arn  = module.database_global.combat_logs_table_arn
  github_actions_role_arn = module.security.github_actions_role_arn
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
  instance_types = ["t4g.medium"]
  desired_size   = 2
  max_size       = 3
  min_size       = 2
  player_state_table_arn = module.database_global.player_state_table_arn
  combat_logs_table_arn  = module.database_global.combat_logs_table_arn
  github_actions_role_arn = module.security.github_actions_role_arn
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

# --- K8s Management via Terraform (since user doesn't have kubectl) ---

resource "kubernetes_namespace" "constellation" {
  metadata {
    name = "constellation"
  }
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"

  set {
    name  = "clusterName"
    value = module.compute_eks_us.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.compute_eks_us.alb_controller_role_arn
  }

  set {
    name  = "vpcId"
    value = module.networks_us.vpc_id
  }

  set {
    name  = "region"
    value = "us-east-1"
  }

  depends_on = [
    module.compute_eks_us
  ]
}

# --- Automated Deploy of Services ---

module "kubernetes_deploy_us" {
  source = "../../modules/kubernetes-deploy"

  project_name            = var.project_name
  environment             = "staging"
  region                  = "us-east-1"
  
  # Estes valores virão do seu build do GitHub Actions
  auth_image              = "721529235452.dkr.ecr.us-east-1.amazonaws.com/constellation-fabric-staging-auth:latest"
  combat_image            = "721529235452.dkr.ecr.us-east-1.amazonaws.com/constellation-fabric-staging-combat:latest"
  
  player_state_table_name = module.database_global.player_state_table_name
  combat_logs_table_name  = module.database_global.combat_logs_table_name
  
  auth_irsa_role_arn      = module.compute_eks_us.auth_irsa_role_arn
  combat_irsa_role_arn     = module.compute_eks_us.combat_irsa_role_arn

  depends_on = [
    helm_release.aws_lb_controller,
    kubernetes_namespace.constellation
  ]
}

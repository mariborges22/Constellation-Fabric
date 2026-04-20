output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_certificate_authority_data" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}

output "oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.eks.arn
}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}

output "auth_irsa_role_arn" {
  value = aws_iam_role.auth_irsa.arn
}

output "combat_irsa_role_arn" {
  value = aws_iam_role.combat_irsa.arn
}

# Output para forçar a dependência do Access Entry
output "access_entry_ready" {
  value      = aws_eks_access_policy_association.terraform_admin.id
  depends_on = [aws_eks_access_policy_association.terraform_admin]
}

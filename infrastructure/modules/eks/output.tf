# modules/eks/outputs.tf

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Endpoint for EKS cluster"
  value       = module.eks.cluster_endpoint
}

output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "oidc_provider_arn" {
  description = "OIDC provider ARN (needed for IRSA)"
  value       = module.eks.oidc_provider_arn
}

output "cluster_ca_certificate" {
  description = "certificate for provider"
  value = module.eks.cluster_certificate_authority_data
}

output "lb_controller_role_arn" {
  description = "ARN of IAM role for AWS Load Balancer Controller"
  value       = module.lb_controller_irsa.iam_role_arn
}
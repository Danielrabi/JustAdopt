# infra/live/dev/eks-addons/terragrunt.hcl
# Installs add-ons into the EKS cluster

terraform {
  source = "../../../modules/eks-addons"
}

# This depends on BOTH VPC and EKS being ready
dependency "vpc" {
  config_path = "../vpc"
  
  mock_outputs = {
    vpc_id = "vpc-fake"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

dependency "eks" {
  config_path = "../eks"
  
  mock_outputs = {
    cluster_name      = "fake-cluster"
    oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/fake"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

inputs = {
  region            = "us-east-1"
  cluster_name      = dependency.eks.outputs.cluster_name
  vpc_id            = dependency.vpc.outputs.vpc_id
  oidc_provider_arn = dependency.eks.outputs.oidc_provider_arn
  env               = "dev"
}

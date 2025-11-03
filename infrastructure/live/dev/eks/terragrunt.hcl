terraform {
  source = "../../..//modules/eks"
}

dependency "vpc" {
  config_path = "../../../foundation/dev/vpc"
}

inputs = {
  cluster_name = "dev-eks"
  region       = "us-east-1"
  vpc_id       = dependency.vpc.outputs.vpc_id
  private_subnet_ids   = dependency.vpc.outputs.private_subnet_ids
  public_subnet_ids    = dependency.vpc.outputs.public_subnet_ids
  env          = "dev"
}
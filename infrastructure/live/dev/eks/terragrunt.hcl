terraform {
  source = "../../..//modules/eks"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  cluster_name = "dev-eks"
  region       = "us-east-1"
  vpc_id       = dependency.vpc.outputs.vpc_id
  subnet_ids   = dependency.vpc.outputs.private_subnet_ids
  env          = "dev"
}
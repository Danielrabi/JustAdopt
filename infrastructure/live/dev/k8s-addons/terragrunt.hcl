terraform {
  source = "../../..//modules/k8s-addons"
}

dependency "vpc"{
  config_path = "../../../foundation/dev/vpc"
}
dependency "eks" {
  config_path = "../eks"
}
dependency "s3" {
  config_path = "../../../foundation/dev/s3"
}
dependency "rds" {
  config_path = "../../../foundation/dev/rds"
}

inputs = {
    env = "dev"
    branch = "helm"
    repourl = "https://github.com/Danielrabi/JustAdopt.git"
    host = dependency.eks.outputs.cluster_endpoint
    cluster_ca_certificate = dependency.eks.outputs.cluster_ca_certificate
    cluster_name = dependency.eks.outputs.cluster_name
    lb_controller_irsa = dependency.eks.outputs.lb_controller_role_arn
    oidc_provider = dependency.eks.outputs.oidc_provider_arn
    vpc_id = dependency.vpc.outputs.vpc_id
    region = "us-east-1"
    bucket_name = dependency.s3.outputs.s3_bucket_name
    bucket_arn = dependency.s3.outputs.s3_bucket_arn
    db_endpoint            = dependency.rds.outputs.db_endpoint
    db_username            = dependency.rds.outputs.db_username
    db_password_secret_arn = dependency.rds.outputs.db_password_secret_arn
}
terraform {
  source = "../../../modules/db"
}

# This depends on the VPC, which you are moving to the foundation layer
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  env = "dev"
  db_name = "dog_list"
  vpc_id = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  instance_class = "db.t3.micro"
  allocated_storage = 20
}
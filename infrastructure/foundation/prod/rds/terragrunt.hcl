terraform {
  source = "../../../modules/db"
}

# This depends on the VPC
dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  env = "prod"
  db_name = "dog_list"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  vpc_id = dependency.vpc.outputs.vpc_id
  private_subnet_ids = dependency.vpc.outputs.private_subnet_ids
  engine_version = "8.0"
}
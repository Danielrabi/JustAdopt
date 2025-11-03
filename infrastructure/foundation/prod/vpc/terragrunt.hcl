terraform {
  source = "../../../modules/vpc"
}

inputs = {
  name   = "prod-vpc"
  region = "us-east-1"
  env    = "prod"
}
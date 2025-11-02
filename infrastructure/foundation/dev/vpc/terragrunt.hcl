terraform {
  source = "../../..//modules/vpc"
}

inputs = {
  name   = "dev-vpc"
  region = "us-east-1"
  env    = "dev"
}
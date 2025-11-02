variable "db_name" {}
variable "engine_version" { default = "8.0" }
variable "instance_class" { default = "db.t3.micro" }
variable "allocated_storage" { default = 20 }
variable "vpc_id" {}
variable "private_subnet_ids" { type = list(string) }
variable "cluster_security_group_id" {} // From EKS
variable "env" {}
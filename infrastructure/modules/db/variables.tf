variable "db_name" {}
variable "vpc_id" {}
variable "private_subnet_ids" { type = list(string) }
variable "env" {}
variable "instance_class" {}
variable "allocated_storage" {}
variable "engine_version" {}
variable "vpc_cidr" {default = "10.0.0.0/16"}
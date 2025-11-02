variable "db_name" {}
variable "vpc_id" {}
variable "private_subnet_ids" { type = list(string) }
variable "env" {}
variable "engine_version" { default = "8.0" }
variable "instance_class" {}
variable "allocated_storage" {}
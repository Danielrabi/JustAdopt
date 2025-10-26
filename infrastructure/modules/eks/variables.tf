variable "cluster_name" {}
variable "region" {}
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "env" {}
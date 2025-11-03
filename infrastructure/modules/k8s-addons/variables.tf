variable "cluster_name" {}
variable "repourl" {}
variable "branch" {}
variable "env" {}
variable "host" {}
variable "cluster_ca_certificate" {}
variable "lb_controller_irsa" {}
variable "vpc_id" {}
variable "region" {}
variable "bucket_name" {}
variable "bucket_arn" {}
variable "oidc_provider" {}
variable "db_endpoint" {
  description = "The connection endpoint for the RDS instance."
}
variable "db_username" {
  description = "The master username for the database."
}
variable "db_password_secret_arn" {
  description = "The ARN of the AWS Secrets Manager secret for the DB password."
}
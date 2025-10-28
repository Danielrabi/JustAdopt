provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster.token
    load_config_file        = false
  }
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  version          = "5.31.0"
  create_namespace = true

  # set {
  #   name  = "controller.adminPassword"
  #   value = "admin"
  # }

  # set {
  #   name  = "controller.adminUser"
  #   value = "admin"
  # }

  # set {
  #   name  = "server.ingress.enabled"
  #   value = "true"
  # }


  # values = [
  #   file("argocd-values.yml"),
  # ]
}
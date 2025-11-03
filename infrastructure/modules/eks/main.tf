terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

data "aws_eks_cluster_auth" "cluster" {
name = module.eks.cluster_name
}

provider "aws" {
  region = var.region
}

provider "helm" {
  kubernetes = {
host = module.eks.cluster_endpoint
cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
token = data.aws_eks_cluster_auth.cluster.token
load_config_file = false
  }
}

module "ebs_csi_driver_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-ebs-csi-driver"

  attach_ebs_csi_policy = true

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:ebs-csi-controller-sa"]
    }
  }

  tags = {
    Environment = var.env
    Terraform = "true"
  }
}

module "eks" {
  source = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"
  name = var.cluster_name
  kubernetes_version = "1.33"

  addons = {
    coredns = {}
    eks-pod-identity-agent = {
      before_compute = true
    }
    kube-proxy = {}
    vpc-cni = {
      before_compute = true
    }
    aws-ebs-csi-driver = {
      service_account_role_arn = module.ebs_csi_driver_irsa.iam_role_arn
    }
  }
  endpoint_public_access = true
  enable_irsa = true
  enable_cluster_creator_admin_permissions = true
  vpc_id                   = var.vpc_id
  subnet_ids               = var.private_subnet_ids
  control_plane_subnet_ids = var.public_subnet_ids

  # EKS Managed Node Group
  eks_managed_node_groups = {
    nodes1 = {
      ami_type = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      min_size = 1
      max_size = 4
      desired_size = 2
    }
  }

  tags = {
    Environment = var.env
    Terraform = "true"
  }
}

resource "helm_release" "argocd" {
  depends_on = [module.eks]
  name = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart = "argo-cd"
  namespace = "argocd"
  version = "5.31.0"
  create_namespace = true
}

# IAM role for load balancer controller
module "lb_controller_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-aws-load-balancer-controller"

  attach_load_balancer_controller_policy = true

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Environment = var.env
    Terraform = "true"
  }
}
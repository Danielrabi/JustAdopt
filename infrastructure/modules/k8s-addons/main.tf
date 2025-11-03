provider "helm" {
  kubernetes = {
    host                   = var.host
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token
    load_config_file        = false
  }
}

provider "kubernetes" {
  host                   = var.host
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster_auth" "cluster" {
  name = var.cluster_name
}

resource "kubernetes_annotations" "gp2_default" {
  api_version = "storage.k8s.io/v1"
  kind        = "StorageClass"

  metadata {
    name = "gp2"
  }

  annotations = {
    "storageclass.kubernetes.io/is-default-class" = "true"
  }
}

# ... (near your other helm/kubernetes providers) ...

# --- 1. DEFINE THE S3 POLICY FOR FLASK ---
data "aws_iam_policy_document" "flask_s3_policy" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      var.bucket_arn,
      "${var.bucket_arn}/*" # Allow access to objects *within* the bucket
    ]
  }
  statement {
    actions = ["s3:HeadBucket"]
    resources = [var.bucket_arn]
  }
}

resource "aws_iam_policy" "flask_s3_policy" {
  name   = "${var.cluster_name}-flask-s3-policy"
  policy = data.aws_iam_policy_document.flask_s3_policy.json
}

module "flask_s3_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "${var.cluster_name}-flask-app"
  role_policy_arns = {
    flask-s3-policy = aws_iam_policy.flask_s3_policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider
      namespace_service_accounts = ["default:${var.env}-app-myapp-flask-sa"]
    }
  }

  tags = {
    Environment = var.env
    Terraform   = "true"
  }
}

resource "kubernetes_manifest" "my_app" {

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "Application"
    metadata = {
      name      = "${var.env}-app"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL        = var.repourl
        targetRevision = var.branch
        path           = "myapp"
        helm = {
          parameters = [
            {
              name  = "flask.env.S3_BUCKET_NAME"
              value = var.bucket_name
            },
            {
              name  = "flask.serviceAccount.roleArn"
              value = tostring(module.flask_s3_irsa.iam_role_arn)
            }
          ]
        }
      }
      destination = {
        server    = "https://kubernetes.default.svc"
        namespace = "default"
      }
      syncPolicy = {
        automated = {
          prune = true
          selfHeal = true
        }
      }
    }
  }
}

# Install AWS Load Balancer Controller via Helm
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  set = [
    {
      name  = "clusterName"
      value = var.cluster_name
    },
    {
      name  = "serviceAccount.create"
      value = "true"
    },
    {
      name  = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.lb_controller_irsa
    },
    {
      name  = "region"
      value = var.region
    },
    {
      name  = "vpcId"
      value = var.vpc_id
    }
  ]
}

# Install NGINX Ingress Controller via Helm
resource "helm_release" "nginx_ingress_controller" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true
  version    = "4.10.1"

  set = [
    {
      name  = "controller.service.type"
      value = "NodePort"
    },
    {
      name = "controller.ingressClassResource.name"
      value = "nginx"
    },
    {
      name = "controller.ingressClassResource.default"
      value = "false"
    },
    {
      name = "controller.ingressClass"
      value = "nginx"
    }
  ]
}

# This is the "ALB" for NGINX
resource "kubernetes_manifest" "nginx_ingress_alb" {
  # Depends on both controllers being ready
  depends_on = [
    helm_release.aws_load_balancer_controller,
    helm_release.nginx_ingress_controller
  ]

  manifest = {
    "apiVersion" = "networking.k8s.io/v1"
    "kind" = "Ingress"
    "metadata" = {
      "name" = "nginx-controller-alb"
      "namespace" = "ingress-nginx"
      "annotations" = {
        # This line tells the AWS ALB Controller to handle this Ingress
        "kubernetes.io/ingress.class" = "alb"
        # Specify target type as IP to work with NGINX NodePort service
        "alb.ingress.kubernetes.io/target-type" = "ip"
        
        # Specify it's an internet-facing ALB
        "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      }
    }
    "spec" = {
      # This line specifies the AWS ALB controller
      "ingressClassName" = "alb"
      "rules" = [
        {
          "http" = {
            "paths" = [
              {
                "path" = "/"
                "pathType" = "Prefix"
                "backend" = {
                  "service" = {
                    # This must match the service name created by the nginx helm chart
                    "name" = "ingress-nginx-controller" 
                    "port" = {
                      "name" = "http" 
                    }
                  }
                }
              }
            ]
          }
        }
      ]
    }
  }
}
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

# allows cluster to use EBS volumes
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

data "aws_iam_policy_document" "flask_s3_policy" {
  statement {
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      var.bucket_arn,
      "${var.bucket_arn}/*"
    ]
  }
  statement {
    actions = ["s3:HeadBucket"]
    resources = [var.bucket_arn]
  }
}

# database password
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = var.db_password_secret_arn
}

resource "aws_iam_policy" "flask_s3_policy" {
  name = "${var.cluster_name}-flask-s3-policy"
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
      provider_arn = var.oidc_provider
      namespace_service_accounts = ["default:${var.env}-app-myapp-flask-sa"]
    }
  }

  tags = {
    Environment = var.env
    Terraform = "true"
  }
}

# Deploy the Flask app via ArgoCD
resource "kubernetes_manifest" "my_app" {

  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind = "Application"
    metadata = {
      name = "${var.env}-app"
      namespace = "argocd"
    }
    spec = {
      project = "default"
      source = {
        repoURL = var.repourl
        targetRevision = var.branch
        path = "myapp"
        helm = {
          # Inject environment variables to the Flask app
          parameters = [
            {
              name = "flask.env.S3_BUCKET_NAME"
              value = var.bucket_name
            },
            {
              name = "flask.serviceAccount.roleArn"
              value = tostring(module.flask_s3_irsa.iam_role_arn)
            },
            {
              name = "flask.env.DB_HOST"
              value = var.db_endpoint
            },
            {
              name = "flask.env.DB_USER"
              value = var.db_username
            },
            {
              name = "flask.env.DB_PASSWORD"
              value = data.aws_secretsmanager_secret_version.db_password.secret_string
            },
            {
              name = "flask.env.DB_NAME"
              value = "dog_list"
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

# Install AWS Load Balancer Controller
resource "helm_release" "aws_load_balancer_controller" {
  name = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart = "aws-load-balancer-controller"
  namespace = "kube-system"
  version = "1.8.1"

  set = [
    {
      name = "clusterName"
      value = var.cluster_name
    },
    {
      name = "serviceAccount.create"
      value = "true"
    },
    {
      name = "serviceAccount.name"
      value = "aws-load-balancer-controller"
    },
    {
      name = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = var.lb_controller_irsa
    },
    {
      name = "region"
      value = var.region
    },
    {
      name = "vpcId"
      value = var.vpc_id
    }
  ]
}

# Install NGINX Ingress Controller via Helm
resource "helm_release" "nginx_ingress_controller" {
  name = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart = "ingress-nginx"
  namespace = "ingress-nginx"
  create_namespace = true
  version = "4.10.1"

  set = [
    {
      name = "controller.service.type"
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

# Create an Ingress resource that uses the AWS ALB to route traffic to the NGINX Ingress Controller
resource "kubernetes_manifest" "nginx_ingress_alb" {
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
        "kubernetes.io/ingress.class" = "alb"
        "alb.ingress.kubernetes.io/target-type" = "ip"
        "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      }
    }
    "spec" = {
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
                    # Name must match the NGINX Ingress Controller from the helm chart
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
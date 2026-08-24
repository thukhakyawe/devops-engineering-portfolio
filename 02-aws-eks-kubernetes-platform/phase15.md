Phase 15 — AWS EKS Kubernetes Platform

We’ll treat it as a clean implementation from scratch, independent of the broken Phase 14 implementation.

We'll keep Phase 14 out of the implementation path.

terraform apply -target=module.networking
terraform apply -target=module.eks
terraform apply -target=module.node_group
terraform apply -target=aws_eks_addon.pod_identity_agent
terraform apply -target=module.external_secrets
terraform apply -target=helm_release.external_secrets
terraform apply -target=module.application_config
terraform apply -target=module.application

STAGE 1
AWS foundation
├── networking
├── IAM
└── EKS

        ↓

STAGE 2
EKS compute
└── node group

        ↓

STAGE 3
Kubernetes platform
├── namespaces
├── AWS Load Balancer Controller
├── External Secrets
└── Karpenter

        ↓

STAGE 4
Application
├── application config
├── application
└── ingress

        ↓

FINAL
terraform apply

Stage 1

Use Terraform targeting to create only the AWS foundation:

terraform -chdir=terraform apply \
  -target=module.networking \
  -target=module.iam \
  -target=module.eks

This should create:

VPC
├── subnets
├── route tables
├── NAT
└── security groups

IAM
├── EKS role
└── node role

EKS
└── eks-platform-dev

It will not create your application, ingress, External Secrets, Karpenter CRDs, etc.

After it completes

Run:

aws eks describe-cluster \
  --name eks-platform-dev \
  --region ap-southeast-1 \
  --query 'cluster.status'

Expected:

"ACTIVE"

Then configure kubectl:

aws eks update-kubeconfig \
  --name eks-platform-dev \
  --region ap-southeast-1

Stage 2 — create the node group

Once the EKS cluster is ACTIVE:

terraform -chdir=terraform apply \
  -target=module.node_group

Then:

kubectl get nodes

We want:

STATUS
Ready

for the nodes.

Stage 3: Kubernetes foundation

Now let's create the Kubernetes namespaces only.

Your configuration has:

module "namespaces" {
  source = "./modules/namespaces"

  namespaces = [
    "platform",
    "application",
    "monitoring"
  ]
}

Run:

terraform -chdir=terraform apply \
  -target=module.namespaces

Approve it.

Then verify:

kubectl get namespaces

You should see:

application
monitoring
platform

And verify Terraform state:

terraform -chdir=terraform state list | grep module.namespaces

You should get three namespace resources.



Stage 4 — Application configuration

The sequence will be:

Stage 4A
├── External Secrets AWS/IAM prerequisites
└── External Secrets Operator

Stage 4B
├── EKS Pod Identity Agent
├── Secrets Manager secret/version
└── Application configuration
    ├── ClusterSecretStore
    └── ExternalSecret

There is one important ordering adjustment: because your External Secrets IAM module now has a dependency on the Pod Identity Agent, install the Pod Identity Agent first.

nstall EKS Pod Identity Agent

Since we're rebuilding this properly as Phase 15, I recommend managing the agent with Terraform rather than manually installing it.

Add this to your Terraform root, as eks-addons.tf:

resource "aws_eks_addon" "pod_identity_agent" {
  cluster_name = module.eks.cluster_name
  addon_name   = "eks-pod-identity-agent"

  depends_on = [
    module.node_group
  ]
}

pprove with:

yes

Then verify:

kubectl get daemonset -n kube-system | grep -i pod

We expect:

eks-pod-identity-agent   2   2   2   ...

Then:

kubectl get pods -n kube-system \
  -l app.kubernetes.io/instance=eks-pod-identity-agent \
  -o wide

Because you have two nodes, we want two Running pods.


1. Change terraform/secrets.tf

Use:

resource "aws_secretsmanager_secret" "application" {
  name = "${var.environment}/platform-api/database"

  description = "Database credentials for the platform API."

  tags = {
    Environment = var.environment
    Application = "platform-api"
  }
}

resource "aws_secretsmanager_secret_version" "application" {
  secret_id = aws_secretsmanager_secret.application.id

  secret_string = jsonencode({
    username = var.database_username
    password = var.database_password
  })
}

2. Add variables

In terraform/variables.tf:

variable "database_username" {
  description = "Database username for the platform API."
  type        = string
  sensitive   = true
}

variable "database_password" {
  description = "Database password for the platform API."
  type        = string
  sensitive   = true
}

3. Put the values in your local tfvars

For example, create:

terraform/terraform.tfvars

with:

database_username = "platform"
database_password = "CHANGE_ME_TO_A_STRONG_PASSWORD"


4A-2 — Install External Secrets AWS/IAM prerequisites

Now run:

terraform -chdir=terraform apply \
  -target=module.external_secrets

This should create:

IAM role
IAM policy
IAM policy attachment
EKS Pod Identity association

Verify the association:

aws eks list-pod-identity-associations \
  --cluster-name eks-platform-dev \
  --region ap-southeast-1

We want:

external-secrets
external-secrets

for namespace/service account.

Also:

terraform -chdir=terraform state list | grep module.external_secrets

4A-3 — Install External Secrets Operator

Now install the Helm release:

terraform -chdir=terraform apply \
  -target=helm_release.external_secrets

Then:

kubectl get pods -n external-secrets

We want the ESO components Running.

Then verify the CRDs:

kubectl get crd | grep external-secrets.io

Expected at minimum:

clustersecretstores.external-secrets.io
externalsecrets.external-secrets.io
secretstores.external-secrets.io

Then:

kubectl api-resources | grep external-secrets

We want:

clustersecretstores
externalsecrets
secretstores

4B — Recreate the application configuration

Now that:

Pod Identity Agent       ✅
External Secrets IAM     ✅
ESO                       ✅
ESO CRDs                  ✅

exist, we can create the Kubernetes resources.

But first, your existing AWS secret needs to be brought under Terraform management.

4B-1 — Import existing Secrets Manager secret

Because the AWS secret already exists, do not create aws_secretsmanager_secret.application again.

Then:

terraform -chdir=terraform state list | grep secretsmanager

We want:

aws_secretsmanager_secret.application

4B-2 — Verify your new secret-version configuration


terraform -chdir=terraform apply \
  -target=aws_secretsmanager_secret_version.application

4B-3 — Create ClusterSecretStore + ExternalSecret

Now run:

terraform -chdir=terraform apply \
  -target=module.application_config

This should now be able to create:

platform-api-config
aws-secretsmanager
platform-api-database

because the External Secrets CRDs already exist.

Then verify:

kubectl get configmap -n application
kubectl get clustersecretstore
kubectl get externalsecret -n application
kubectl get secret -n application

Stage 4C Application

The log gives us the root cause:

mkdir() "/var/cache/nginx/client_temp" failed (30: Read-only file system)

Your read_only_root_filesystem = true is incompatible with the default nginx:1.27-alpine runtime configuration. Nginx needs to write to /var/cache/nginx.

For this Phase 15 implementation, I recommend keeping the security hardening and giving nginx writable emptyDir mounts rather than disabling read_only_root_filesystem.

In terraform/modules/application/main.tf, update with this

resource "kubernetes_deployment" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace

    labels = {
      app = var.name
    }
  }

  lifecycle {
    ignore_changes = [
      spec[0].replicas
    ]
  }

  spec {
    replicas = var.min_replicas

    strategy {
      type = "RollingUpdate"

      rolling_update {
        max_unavailable = "25%"
        max_surge       = "25%"
      }
    }

    selector {
      match_labels = {
        app = var.name
      }
    }

    template {
      metadata {
        labels = {
          app = var.name
        }
      }

      spec {
        security_context {
          run_as_non_root = true

          seccomp_profile {
            type = "RuntimeDefault"
          }
        }

        container {
          name  = var.name
          image = var.image

          security_context {
            allow_privilege_escalation = false
            privileged                 = false
            read_only_root_filesystem  = true

            capabilities {
              drop = ["ALL"]
            }
          }

          port {
            container_port = var.container_port
          }

          env_from {
            config_map_ref {
              name = var.config_map_name
            }
          }

          volume_mount {
            name       = "nginx-cache"
            mount_path = "/var/cache/nginx"
          }

          volume_mount {
            name       = "nginx-run"
            mount_path = "/var/run"
          }

          volume_mount {
            name       = "tmp"
            mount_path = "/tmp"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }

            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          startup_probe {
            http_get {
              path = "/"
              port = var.container_port
            }

            failure_threshold = 30
            period_seconds    = 5
          }

          readiness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }

            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 2
            failure_threshold     = 3
            success_threshold     = 1
          }

          liveness_probe {
            http_get {
              path = "/"
              port = var.container_port
            }

            initial_delay_seconds = 15
            period_seconds        = 20
            timeout_seconds       = 2
            failure_threshold     = 3
            success_threshold     = 1
          }
        }

        volume {
          name = "nginx-cache"

          empty_dir {}
        }

        volume {
          name = "nginx-run"

          empty_dir {}
        }

        volume {
          name = "tmp"

          empty_dir {}
        }
      }
    }
  }
}

resource "kubernetes_service" "this" {
  metadata {
    name      = var.name
    namespace = var.namespace
  }

  spec {
    selector = {
      app = var.name
    }

    port {
      port        = 80
      target_port = var.container_port
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}


But one more nginx issue

Your log also shows:

can not modify /etc/nginx/conf.d/default.conf
(read-only file system?)

That message by itself isn't fatal. The fatal error is:

mkdir() "/var/cache/nginx/client_temp" failed

So let's fix /var/cache/nginx first rather than making unnecessary changes to the image or security model.

Change terraform/main.tf

Replace:

module "application" {
  source = "./modules/application"

  namespace = "application"

  name = "platform-api"

  image = "nginx:1.27-alpine"

  replicas = 2

  container_port = 80

  config_map_name = module.application_config.config_map_name
}


with:

module "application" {
  source = "./modules/application"

  namespace = "application"

  name = "platform-api"

  image = "nginxinc/nginx-unprivileged:1.27-alpine"

  replicas = 2

  container_port = 8080

  config_map_name = module.application_config.config_map_name
}

and change container_port in terraform/modules/application/variables.tf

variable "container_port" {
  description = "Application container port."
  type        = number
  default     = 8080
}


Run:

terraform -chdir=terraform apply \
  -target=module.application

Approve with:

yes

Then verify:

kubectl rollout status deployment/platform-api \
  -n application
kubectl get deployment -n application
kubectl get pods \
  -n application \
  -l app=platform-api
kubectl get service -n application
kubectl get hpa -n application
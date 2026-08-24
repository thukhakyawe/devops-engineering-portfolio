Phase 15 — AWS EKS Kubernetes Platform

We’ll treat it as a clean implementation from scratch, independent of the broken Phase 14 implementation.

We'll keep Phase 14 out of the implementation path.

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